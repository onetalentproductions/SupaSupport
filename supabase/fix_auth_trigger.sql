-- Fix: "Access Denied: Restrained to official @fbcvr.com corporate email addresses"
--
-- ⚠️  If you still see "Restrained to official @fbcvr.com" AFTER running this file,
--     the blocker is a Supabase AUTH HOOK, not this trigger.
--     Run: supabase/fix_before_user_created_hook.sql
--     Or disable: Dashboard → Authentication → Hooks → Before user created → OFF
--
-- An OLD trigger/function may still exist in Supabase (not from our latest schema files).
-- Run this entire script in Supabase SQL Editor.

-- =============================================================================
-- STEP 1: Find the old function (run this first to see what exists)
-- =============================================================================
SELECT n.nspname AS schema, p.proname AS function_name
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prosrc ILIKE '%Restrained to official%'
   OR p.prosrc ILIKE '%corporate email addresses%';

SELECT tgname AS trigger_name, pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t
WHERE t.tgrelid = 'auth.users'::regclass
  AND NOT t.tgisinternal;

-- =============================================================================
-- STEP 2: Drop ALL custom triggers on auth.users, then drop old functions
-- =============================================================================

DO $$
DECLARE
    trigger_record RECORD;
    func_record RECORD;
BEGIN
    -- Drop every non-internal trigger on auth.users
    FOR trigger_record IN
        SELECT tgname
        FROM pg_trigger
        WHERE tgrelid = 'auth.users'::regclass
          AND NOT tgisinternal
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users', trigger_record.tgname);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.tgname;
    END LOOP;

    -- Drop functions containing the old error message
    FOR func_record IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.prosrc ILIKE '%Restrained to official%'
           OR p.prosrc ILIKE '%corporate email addresses%'
           OR p.proname IN ('restrict_fbcvr_domain', 'enforce_fbcvr_email', 'check_fbcvr_domain')
    LOOP
        EXECUTE format(
            'DROP FUNCTION IF EXISTS %I.%I(%s) CASCADE',
            func_record.nspname,
            func_record.proname,
            func_record.args
        );
        RAISE NOTICE 'Dropped function: %.%(%)', func_record.nspname, func_record.proname, func_record.args;
    END LOOP;
END $$;

-- =============================================================================
-- STEP 3: Install the updated allowlist (includes test Gmail accounts)
-- =============================================================================

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

CREATE OR REPLACE FUNCTION public.restrict_fbcvr_domain()
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

    IF NOT public.is_allowed_email(user_email) THEN
        RAISE EXCEPTION 'Email % is not allowed. Use @fbcvr.com or an approved test account.', user_email;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER restrict_fbcvr_domain_trigger
    BEFORE INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.restrict_fbcvr_domain();

-- =============================================================================
-- STEP 4: Verify
-- =============================================================================
SELECT public.is_allowed_email('csmith30615@gmail.com') AS csmith_ok,
       public.is_allowed_email('onetalentproductions@gmail.com') AS admin_ok,
       public.is_allowed_email('random@gmail.com') AS random_blocked;

SELECT tgname FROM pg_trigger
WHERE tgrelid = 'auth.users'::regclass AND NOT tgisinternal;
-- Should show only: restrict_fbcvr_domain_trigger
