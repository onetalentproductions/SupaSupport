-- Hide completed tickets from end-user lists by default (toggle in app shows them).
-- Users can still SELECT own completed tickets when the eye toggle is on.
-- Run in Supabase SQL Editor if you previously ran the stricter version.

DROP POLICY IF EXISTS "Users read own tickets" ON tickets;
CREATE POLICY "Users read own tickets" ON tickets
    FOR SELECT USING (
        auth.uid() = user_id
        OR (
            admin_department() IS NOT NULL
            AND department = admin_department()
        )
    );
