-- Add Apple App Store review account to the sign-up allowlist.
-- Run this entire script in Supabase SQL Editor.

CREATE OR REPLACE FUNCTION public.is_allowed_email(email TEXT)
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

-- Verify review account is allowed (should return true)
SELECT public.is_allowed_email('fbcvrtickets.review@gmail.com') AS review_account_ok;
