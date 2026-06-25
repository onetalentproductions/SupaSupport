-- FBCVRTickets Database Schema
-- Run this in the Supabase SQL Editor for project atgrgtkbwfcxvibgkqla

-- =============================================================================
-- ENUMS (stored as TEXT with CHECK constraints for simplicity)
-- priority: low, medium, high, urgent
-- status: open, complete, out_of_scope
-- department: media, facilities
-- file_type: image, video
-- =============================================================================

-- Drop existing simple tickets table if it only had id/user_id/title
-- Comment out the next line if you have production data to preserve
-- DROP TABLE IF EXISTS tickets CASCADE;

-- =============================================================================
-- MIGRATION: If you already have a simple tickets table, run these ALTERs first
-- =============================================================================
-- ALTER TABLE tickets ADD COLUMN IF NOT EXISTS user_email TEXT;
-- ALTER TABLE tickets ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '';
-- ALTER TABLE tickets ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'medium';
-- ALTER TABLE tickets ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'open';
-- ALTER TABLE tickets ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
-- ALTER TABLE tickets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
-- ALTER TABLE tickets ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
-- ALTER TABLE tickets ADD COLUMN IF NOT EXISTS completed_by_email TEXT;
-- ALTER TABLE tickets ADD COLUMN IF NOT EXISTS department TEXT NOT NULL DEFAULT 'facilities';

CREATE TABLE IF NOT EXISTS tickets (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_email  TEXT NOT NULL,
    title       TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    priority    TEXT NOT NULL DEFAULT 'medium'
                CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status      TEXT NOT NULL DEFAULT 'open'
                CHECK (status IN ('open', 'complete', 'out_of_scope')),
    department  TEXT NOT NULL DEFAULT 'facilities'
                CHECK (department IN ('media', 'facilities')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    completed_by_email TEXT
);

CREATE TABLE IF NOT EXISTS ticket_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id   UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_email  TEXT NOT NULL,
    is_admin    BOOLEAN NOT NULL DEFAULT false,
    body        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ticket_attachments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id  UUID NOT NULL REFERENCES ticket_messages(id) ON DELETE CASCADE,
    ticket_id   UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    file_path   TEXT NOT NULL,
    file_type   TEXT NOT NULL CHECK (file_type IN ('image', 'video')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tickets_user_id ON tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_department ON tickets(department);
CREATE INDEX IF NOT EXISTS idx_tickets_department_status ON tickets(department, status);
CREATE INDEX IF NOT EXISTS idx_tickets_created_at ON tickets(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ticket_messages_ticket_id ON ticket_messages(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_attachments_message_id ON ticket_attachments(message_id);

-- Auto-update updated_at on tickets
CREATE OR REPLACE FUNCTION update_ticket_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tickets_updated_at ON tickets;
CREATE TRIGGER tickets_updated_at
    BEFORE UPDATE ON tickets
    FOR EACH ROW EXECUTE FUNCTION update_ticket_timestamp();

-- =============================================================================
-- ADMIN HELPER
-- =============================================================================

CREATE OR REPLACE FUNCTION is_allowed_email(email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF email IS NULL OR trim(email) = '' THEN
        RETURN false;
    END IF;

    RETURN lower(trim(email)) LIKE '%@fbcvr.com'
        OR lower(trim(email)) IN (
            'csmith30615@gmail.com',
            'onetalentproductions@gmail.com',
            'fbcvrtickets.review@gmail.com'
        );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION admin_department()
RETURNS TEXT AS $$
BEGIN
    RETURN CASE lower(auth.jwt() ->> 'email')
        WHEN 'austinsmith@fbcvr.com' THEN 'media'
        WHEN 'zack@fbcvr.com' THEN 'media'
        WHEN 'onetalentproductions@gmail.com' THEN 'media'
        WHEN 'sonya@fbcvr.com' THEN 'facilities'
        WHEN 'hunter@fbcvr.com' THEN 'facilities'
        ELSE NULL
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN admin_department() IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION get_department_completion_counts()
RETURNS TABLE(media_count BIGINT, facilities_count BIGINT)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    RETURN QUERY
    SELECT
        count(*) FILTER (WHERE department = 'media' AND status = 'complete')::BIGINT,
        count(*) FILTER (WHERE department = 'facilities' AND status = 'complete')::BIGINT
    FROM tickets;
END;
$$;

GRANT EXECUTE ON FUNCTION get_department_completion_counts() TO authenticated;

-- Restrict sign-ups to @fbcvr.com or approved test accounts
CREATE OR REPLACE FUNCTION restrict_fbcvr_domain()
RETURNS TRIGGER AS $$
DECLARE
    user_email TEXT;
BEGIN
    user_email := lower(trim(coalesce(
        NEW.email,
        NEW.raw_user_meta_data->>'email',
        ''
    )));

    IF user_email = '' THEN
        RETURN NEW;
    END IF;

    IF NOT is_allowed_email(user_email) THEN
        RAISE EXCEPTION 'Email % is not allowed. Use @fbcvr.com or an approved test account.', user_email;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS restrict_fbcvr_domain_trigger ON auth.users;
CREATE TRIGGER restrict_fbcvr_domain_trigger
    BEFORE INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION restrict_fbcvr_domain();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_attachments ENABLE ROW LEVEL SECURITY;

-- Tickets: users see own; department admins see tickets in their department
DROP POLICY IF EXISTS "Users read own tickets" ON tickets;
CREATE POLICY "Users read own tickets" ON tickets
    FOR SELECT USING (
        auth.uid() = user_id
        OR (
            admin_department() IS NOT NULL
            AND department = admin_department()
        )
    );

DROP POLICY IF EXISTS "Users create own tickets" ON tickets;
CREATE POLICY "Users create own tickets" ON tickets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins update tickets" ON tickets;
CREATE POLICY "Admins update tickets" ON tickets
    FOR UPDATE
    USING (admin_department() IS NOT NULL AND department = admin_department())
    WITH CHECK (admin_department() IS NOT NULL);

-- Messages: readable by ticket owner or admin
DROP POLICY IF EXISTS "Read ticket messages" ON ticket_messages;
CREATE POLICY "Read ticket messages" ON ticket_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM tickets t
            WHERE t.id = ticket_id
            AND (t.user_id = auth.uid() OR is_admin())
        )
    );

DROP POLICY IF EXISTS "Insert ticket messages" ON ticket_messages;
CREATE POLICY "Insert ticket messages" ON ticket_messages
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM tickets t
            WHERE t.id = ticket_id
            AND t.status = 'open'
            AND (t.user_id = auth.uid() OR is_admin())
        )
    );

-- Attachments: same access as messages
DROP POLICY IF EXISTS "Read attachments" ON ticket_attachments;
CREATE POLICY "Read attachments" ON ticket_attachments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM tickets t
            WHERE t.id = ticket_id
            AND (t.user_id = auth.uid() OR is_admin())
        )
    );

DROP POLICY IF EXISTS "Insert attachments" ON ticket_attachments;
CREATE POLICY "Insert attachments" ON ticket_attachments
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM tickets t
            WHERE t.id = ticket_id
            AND t.status = 'open'
            AND (t.user_id = auth.uid() OR is_admin())
        )
    );

-- =============================================================================
-- STORAGE BUCKET
-- Create in Supabase Dashboard > Storage > New Bucket:
--   Name: ticket-media, Public: true
-- Then run these policies:
-- =============================================================================

-- CREATE POLICY "Authenticated users upload media"
--     ON storage.objects FOR INSERT
--     WITH CHECK (bucket_id = 'ticket-media' AND auth.role() = 'authenticated');

-- CREATE POLICY "Anyone read ticket media"
--     ON storage.objects FOR SELECT
--     USING (bucket_id = 'ticket-media');

-- =============================================================================
-- REALTIME (enable in Supabase Dashboard > Database > Replication)
-- Add tickets, ticket_messages to the supabase_realtime publication
-- =============================================================================
