-- =============================================================================
-- FIX: "Access Denied: Restrained to official @fbcvr.com corporate email addresses"
-- =============================================================================
-- This error comes from a Supabase AUTH HOOK (Before User Created), NOT a trigger.
-- Dropping triggers on auth.users will NOT fix it.
--
-- FASTEST FIX (do this first):
--   Supabase Dashboard → Authentication → Hooks → "Before user created"
--   → Disable the hook (toggle OFF) → Save
--   Then try signing in again.
--
-- PERMANENT FIX: Run this entire SQL file, then point the hook at the new function.
-- =============================================================================

-- STEP 1: Find the old hook function
SELECT p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosrc ILIKE '%Restrained to official%'
   OR p.prosrc ILIKE '%corporate email addresses%'
   OR (p.proname ILIKE '%fbcvr%' AND pg_get_function_identity_arguments(p.oid) LIKE '%jsonb%')
   OR (p.proname ILIKE '%restrict%' AND pg_get_function_identity_arguments(p.oid) LIKE '%jsonb%');

-- STEP 2: Shared allowlist helper
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

-- STEP 3: Drop old hook functions that contain the blocked message
DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.prosrc ILIKE '%Restrained to official%'
           OR p.prosrc ILIKE '%corporate email addresses%'
    LOOP
        EXECUTE format(
            'DROP FUNCTION IF EXISTS %I.%I(%s) CASCADE',
            func_record.nspname,
            func_record.proname,
            func_record.args
        );
        RAISE NOTICE 'Dropped old hook function: %.%(%)',
            func_record.nspname, func_record.proname, func_record.args;
    END LOOP;
END $$;

-- STEP 4: Create the replacement Before User Created hook
CREATE OR REPLACE FUNCTION public.hook_before_user_created(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    user_email TEXT;
BEGIN
    user_email := lower(trim(coalesce(event->'user'->>'email', '')));

    IF user_email = '' THEN
        RETURN '{}'::jsonb;
    END IF;

    IF public.is_allowed_email(user_email) THEN
        RETURN '{}'::jsonb;
    END IF;

    RETURN jsonb_build_object(
        'error', jsonb_build_object(
            'http_code', 403,
            'message', format('Email %s is not allowed. Use @fbcvr.com or an approved test account.', user_email)
        )
    );
END;
$$;

-- STEP 5: Permissions required for Auth Hooks
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) FROM authenticated, anon, public;

-- STEP 6: Verify allowlist
SELECT public.is_allowed_email('csmith30615@gmail.com') AS csmith_ok,
       public.is_allowed_email('onetalentproductions@gmail.com') AS admin_ok,
       public.is_allowed_email('random@gmail.com') AS random_blocked;

-- =============================================================================
-- STEP 7: Update the hook in the Dashboard (required!)
-- =============================================================================
-- Go to: Authentication → Hooks → Before user created
-- Set the Postgres function to: public.hook_before_user_created
-- URI format: pg-functions://postgres/public/hook_before_user_created
-- Enable the hook → Save
--
-- OR leave the hook disabled if you only need test access right now.
