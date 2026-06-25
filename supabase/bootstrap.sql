-- SupaSupport org bootstrap (run once per Supabase project in SQL Editor)
-- Generated/customized via setup at supasupport.net (future)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Organization config
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org_settings (
    id              INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    org_name        TEXT NOT NULL DEFAULT 'My Organization',
    icon_key        TEXT,
    logo_url        TEXT,
    access_mode     TEXT NOT NULL DEFAULT 'invite_only'
                    CHECK (access_mode IN ('invite_only', 'domain', 'open')),
    allowed_domain  TEXT,
    schema_version  INT NOT NULL DEFAULT 1,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO org_settings (org_name) VALUES ('My Organization')
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS departments (
    slug        TEXT PRIMARY KEY,
    label       TEXT NOT NULL,
    sort_order  INT NOT NULL DEFAULT 0,
    color_hex   TEXT
);

INSERT INTO departments (slug, label, sort_order, color_hex) VALUES
    ('facilities', 'Facilities', 0, '#D16B14'),
    ('media', 'Media', 1, '#7338C7')
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Members & invites (replaces hardcoded admin emails)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org_members (
    user_id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email             TEXT,
    role              TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    department_slugs  TEXT[] NOT NULL DEFAULT '{}',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pending_members (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email             TEXT,
    role              TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    department_slugs  TEXT[] NOT NULL DEFAULT '{}',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    claimed_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    claimed_at        TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_members_email
    ON pending_members (lower(trim(email)))
    WHERE email IS NOT NULL AND claimed_by IS NULL;

CREATE TABLE IF NOT EXISTS invites (
    token             TEXT PRIMARY KEY,
    role              TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    department_slugs  TEXT[] NOT NULL DEFAULT '{}',
    email             TEXT,
    created_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    expires_at        TIMESTAMPTZ,
    redeemed_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    redeemed_at       TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Tickets (department is dynamic slug)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tickets (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_email          TEXT NOT NULL,
    title               TEXT NOT NULL,
    description         TEXT NOT NULL DEFAULT '',
    priority            TEXT NOT NULL DEFAULT 'medium'
                        CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status              TEXT NOT NULL DEFAULT 'open'
                        CHECK (status IN ('open', 'complete', 'out_of_scope')),
    department          TEXT NOT NULL REFERENCES departments(slug),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at        TIMESTAMPTZ,
    completed_by_email    TEXT
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

CREATE TABLE IF NOT EXISTS push_device_tokens (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform     TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios')),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, device_token)
);

CREATE INDEX IF NOT EXISTS idx_tickets_user_id ON tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_department ON tickets(department);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_ticket_messages_ticket_id ON ticket_messages(ticket_id);
CREATE INDEX IF NOT EXISTS idx_push_device_tokens_user_id ON push_device_tokens(user_id);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION member_role()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT role FROM org_members WHERE user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION is_org_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT COALESCE((SELECT role = 'admin' FROM org_members WHERE user_id = auth.uid()), false);
$$;

CREATE OR REPLACE FUNCTION member_department_slugs()
RETURNS TEXT[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT COALESCE(
        (SELECT department_slugs FROM org_members WHERE user_id = auth.uid()),
        '{}'::TEXT[]
    );
$$;

CREATE OR REPLACE FUNCTION admin_can_see_department(dept TEXT)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT CASE
        WHEN NOT is_org_admin() THEN false
        WHEN cardinality(member_department_slugs()) = 0 THEN true
        ELSE dept = ANY(member_department_slugs())
    END;
$$;

CREATE OR REPLACE FUNCTION default_department_slug()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT slug FROM departments ORDER BY sort_order, slug LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION get_department_completion_counts()
RETURNS TABLE (slug TEXT, label TEXT, completed_count BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT d.slug, d.label, COUNT(t.id)
    FROM departments d
    LEFT JOIN tickets t ON t.department = d.slug AND t.status = 'complete'
    GROUP BY d.slug, d.label, d.sort_order
    ORDER BY d.sort_order, d.slug;
$$;

CREATE OR REPLACE FUNCTION get_my_membership()
RETURNS JSON
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    m org_members%ROWTYPE;
BEGIN
    SELECT * INTO m FROM org_members WHERE user_id = auth.uid();
    IF NOT FOUND THEN
        RETURN json_build_object('role', null, 'department_slugs', '[]'::json);
    END IF;
    RETURN json_build_object(
        'role', m.role,
        'department_slugs', to_json(m.department_slugs),
        'email', m.email
    );
END;
$$;

CREATE OR REPLACE FUNCTION redeem_invite(p_token TEXT)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    inv invites%ROWTYPE;
    user_email TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT email INTO user_email FROM auth.users WHERE id = auth.uid();

    SELECT * INTO inv FROM invites
    WHERE token = p_token
      AND redeemed_by IS NULL
      AND (expires_at IS NULL OR expires_at > now());

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invite';
    END IF;

    IF inv.email IS NOT NULL AND lower(trim(inv.email)) <> lower(trim(user_email)) THEN
        RAISE EXCEPTION 'This invite was issued for a different email address';
    END IF;

    INSERT INTO org_members (user_id, email, role, department_slugs)
    VALUES (auth.uid(), user_email, inv.role, inv.department_slugs)
    ON CONFLICT (user_id) DO UPDATE SET
        role = EXCLUDED.role,
        department_slugs = EXCLUDED.department_slugs,
        email = EXCLUDED.email;

    UPDATE invites SET redeemed_by = auth.uid(), redeemed_at = now()
    WHERE token = p_token;

    RETURN get_my_membership();
END;
$$;

CREATE OR REPLACE FUNCTION create_invite(
    p_role TEXT DEFAULT 'user',
    p_department_slugs TEXT[] DEFAULT '{}',
    p_email TEXT DEFAULT NULL,
    p_expires_days INT DEFAULT 14
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    tok TEXT;
BEGIN
    IF NOT is_org_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    tok := encode(gen_random_bytes(16), 'hex');

    INSERT INTO invites (token, role, department_slugs, email, created_by, expires_at)
    VALUES (
        tok,
        p_role,
        COALESCE(p_department_slugs, '{}'),
        NULLIF(trim(p_email), ''),
        auth.uid(),
        now() + make_interval(days => COALESCE(p_expires_days, 14))
    );

    RETURN json_build_object('token', tok);
END;
$$;

CREATE OR REPLACE FUNCTION add_pending_member(
    p_email TEXT,
    p_role TEXT DEFAULT 'user',
    p_department_slugs TEXT[] DEFAULT '{}'
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    IF NOT is_org_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    INSERT INTO pending_members (email, role, department_slugs)
    VALUES (lower(trim(p_email)), p_role, COALESCE(p_department_slugs, '{}'));

    RETURN json_build_object('ok', true);
EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Email already pending or added';
END;
$$;

CREATE OR REPLACE FUNCTION claim_pending_membership()
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    user_email TEXT;
    pending pending_members%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF EXISTS (SELECT 1 FROM org_members WHERE user_id = auth.uid()) THEN
        RETURN get_my_membership();
    END IF;

    SELECT email INTO user_email FROM auth.users WHERE id = auth.uid();

    SELECT * INTO pending FROM pending_members
    WHERE lower(trim(email)) = lower(trim(user_email))
      AND claimed_by IS NULL
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No membership found. Ask your admin for an invite.';
    END IF;

    INSERT INTO org_members (user_id, email, role, department_slugs)
    VALUES (auth.uid(), user_email, pending.role, pending.department_slugs);

    UPDATE pending_members SET claimed_by = auth.uid(), claimed_at = now()
    WHERE id = pending.id;

    RETURN get_my_membership();
END;
$$;

CREATE OR REPLACE FUNCTION handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    settings org_settings%ROWTYPE;
    pending pending_members%ROWTYPE;
BEGIN
    SELECT * INTO settings FROM org_settings WHERE id = 1;

    IF settings.access_mode = 'open' THEN
        INSERT INTO org_members (user_id, email, role, department_slugs)
        VALUES (NEW.id, NEW.email, 'user', ARRAY[default_department_slug()])
        ON CONFLICT DO NOTHING;
        RETURN NEW;
    END IF;

    SELECT * INTO pending FROM pending_members
    WHERE email IS NOT NULL
      AND lower(trim(email)) = lower(trim(NEW.email))
      AND claimed_by IS NULL
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
        INSERT INTO org_members (user_id, email, role, department_slugs)
        VALUES (NEW.id, NEW.email, pending.role, pending.department_slugs);
        UPDATE pending_members SET claimed_by = NEW.id, claimed_at = now() WHERE id = pending.id;
        RETURN NEW;
    END IF;

    IF settings.access_mode = 'domain'
       AND settings.allowed_domain IS NOT NULL
       AND NEW.email ILIKE '%' || settings.allowed_domain THEN
        INSERT INTO org_members (user_id, email, role, department_slugs)
        VALUES (NEW.id, NEW.email, 'user', ARRAY[default_department_slug()]);
        RETURN NEW;
    END IF;

    -- invite_only: user must redeem invite after sign-in (or be pre-added above)
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();

CREATE OR REPLACE FUNCTION tickets_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tickets_updated_at ON tickets;
CREATE TRIGGER tickets_updated_at
    BEFORE UPDATE ON tickets
    FOR EACH ROW EXECUTE FUNCTION tickets_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE org_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read org settings" ON org_settings;
CREATE POLICY "read org settings" ON org_settings FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "read departments" ON departments;
CREATE POLICY "read departments" ON departments FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "read own membership" ON org_members;
CREATE POLICY "read own membership" ON org_members FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "admins read members" ON org_members;
CREATE POLICY "admins read members" ON org_members FOR SELECT USING (is_org_admin());

DROP POLICY IF EXISTS "admins manage pending" ON pending_members;
CREATE POLICY "admins manage pending" ON pending_members FOR ALL USING (is_org_admin()) WITH CHECK (is_org_admin());

DROP POLICY IF EXISTS "admins manage invites" ON invites;
CREATE POLICY "admins manage invites" ON invites FOR ALL USING (is_org_admin()) WITH CHECK (is_org_admin());

DROP POLICY IF EXISTS "users read own tickets" ON tickets;
CREATE POLICY "users read own tickets" ON tickets FOR SELECT USING (
    user_id = auth.uid()
    OR admin_can_see_department(department)
);

DROP POLICY IF EXISTS "users create own tickets" ON tickets;
CREATE POLICY "users create own tickets" ON tickets FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (SELECT 1 FROM org_members WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "admins update tickets" ON tickets;
CREATE POLICY "admins update tickets" ON tickets FOR UPDATE USING (
    admin_can_see_department(department)
);

DROP POLICY IF EXISTS "read messages" ON ticket_messages;
CREATE POLICY "read messages" ON ticket_messages FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM tickets t
        WHERE t.id = ticket_id
          AND (t.user_id = auth.uid() OR admin_can_see_department(t.department))
    )
);

DROP POLICY IF EXISTS "insert messages" ON ticket_messages;
CREATE POLICY "insert messages" ON ticket_messages FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM tickets t
        WHERE t.id = ticket_id
          AND (t.user_id = auth.uid() OR admin_can_see_department(t.department))
    )
);

DROP POLICY IF EXISTS "read attachments" ON ticket_attachments;
CREATE POLICY "read attachments" ON ticket_attachments FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM tickets t
        WHERE t.id = ticket_id
          AND (t.user_id = auth.uid() OR admin_can_see_department(t.department))
    )
);

DROP POLICY IF EXISTS "insert attachments" ON ticket_attachments;
CREATE POLICY "insert attachments" ON ticket_attachments FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM tickets t
        WHERE t.id = ticket_id
          AND (t.user_id = auth.uid() OR admin_can_see_department(t.department))
    )
);

DROP POLICY IF EXISTS "Users manage own push tokens" ON push_device_tokens;
CREATE POLICY "Users manage own push tokens" ON push_device_tokens
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Storage bucket: create "ticket-media" in Supabase Dashboard → Storage (public read if needed)

-- First admin bootstrap (replace email, run once after auth user exists OR use invite):
-- INSERT INTO pending_members (email, role, department_slugs)
-- VALUES ('you@example.com', 'admin', ARRAY['media','facilities']);
