-- Hide completed tickets from admin lists (mobile + web) without breaking mark-complete.
-- Run in Supabase SQL Editor — no app rebuild required.
--
-- Admins cannot SELECT completed tickets EXCEPT for ~30 seconds after an update
-- (covers mark-complete + immediate refresh). After that they disappear from lists.

DROP POLICY IF EXISTS "Users read own tickets" ON tickets;

CREATE POLICY "Users read own tickets" ON tickets
    FOR SELECT USING (
        auth.uid() = user_id
        OR (
            is_admin() AND (
                status <> 'complete'
                OR updated_at > now() - interval '30 seconds'
            )
        )
    );

-- Ensure admins can always apply status updates (including marking complete)
DROP POLICY IF EXISTS "Admins update tickets" ON tickets;
CREATE POLICY "Admins update tickets" ON tickets
    FOR UPDATE
    USING (is_admin())
    WITH CHECK (is_admin());
