-- Departments (media / facilities) + department-scoped admin access
-- Run in Supabase SQL Editor before submitting the new app build.
--
-- Also required outside SQL:
--   1. Supabase → Auth → Apple → enable, set Services ID / secret per Supabase docs
--   2. Apple Developer → App ID → enable Sign in with Apple capability
--   3. Xcode → Signing & Capabilities → Sign in with Apple (entitlements file updated)

-- =============================================================================
-- COLUMN
-- =============================================================================

ALTER TABLE tickets
    ADD COLUMN IF NOT EXISTS department TEXT NOT NULL DEFAULT 'facilities'
    CHECK (department IN ('media', 'facilities'));

CREATE INDEX IF NOT EXISTS idx_tickets_department ON tickets(department);
CREATE INDEX IF NOT EXISTS idx_tickets_department_status ON tickets(department, status);

-- =============================================================================
-- ADMIN HELPERS
-- =============================================================================

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

-- Completed ticket counts by department (for analytics bar — all admins)
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

-- =============================================================================
-- RLS — replace ticket policies
-- =============================================================================

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
