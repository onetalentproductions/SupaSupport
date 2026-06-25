-- =============================================================================
-- FIND what's blocking sign-up with:
-- "Access Denied: Restrained to official @fbcvr.com corporate email addresses"
-- =============================================================================
-- Auth Hooks is empty → this is a Postgres TRIGGER or FUNCTION in your database.
-- Run each section in Supabase SQL Editor and read the results.

-- 1) Search ALL functions for the exact error text
SELECT n.nspname AS schema_name,
       p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosrc ILIKE '%Restrained to official%'
   OR p.prosrc ILIKE '%corporate email addresses%'
   OR p.prosrc ILIKE '%fbcvr.com%';

-- 2) Same search via information_schema (sometimes finds what pg_proc misses)
SELECT routine_schema,
       routine_name,
       data_type AS return_type
FROM information_schema.routines
WHERE routine_definition ILIKE '%Restrained to official%'
   OR routine_definition ILIKE '%corporate email addresses%';

-- 3) All custom triggers on auth.users
SELECT tgname AS trigger_name,
       pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
WHERE t.tgrelid = 'auth.users'::regclass
  AND NOT t.tgisinternal;

-- 4) All custom triggers on auth.identities (also runs during OAuth sign-up)
SELECT tgname AS trigger_name,
       pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
WHERE t.tgrelid = 'auth.identities'::regclass
  AND NOT t.tgisinternal;

-- 5) Any public function that looks like email/domain restriction
SELECT n.nspname AS schema_name,
       p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'auth', 'extensions')
  AND (
    p.proname ILIKE '%fbcvr%'
    OR p.proname ILIKE '%restrict%'
    OR p.proname ILIKE '%domain%'
    OR p.proname ILIKE '%email%'
    OR p.proname ILIKE '%hook%'
    OR p.proname ILIKE '%user%created%'
  )
ORDER BY n.nspname, p.proname;

-- =============================================================================
-- NUCLEAR FIX — run this if you want to remove blockers without finding the name
-- =============================================================================

DO $$
DECLARE
    trigger_record RECORD;
    func_record RECORD;
BEGIN
    -- Drop every non-internal trigger on auth.users and auth.identities
    FOR trigger_record IN
        SELECT tgrelid::regclass::text AS table_name, tgname
        FROM pg_trigger
        WHERE tgrelid IN ('auth.users'::regclass, 'auth.identities'::regclass)
          AND NOT tgisinternal
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s',
                      trigger_record.tgname, trigger_record.table_name);
        RAISE NOTICE 'Dropped trigger % on %', trigger_record.tgname, trigger_record.table_name;
    END LOOP;

    -- Drop any function containing the old error message
    FOR func_record IN
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.prosrc ILIKE '%Restrained to official%'
           OR p.prosrc ILIKE '%corporate email addresses%'
    LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s) CASCADE',
                       func_record.nspname, func_record.proname, func_record.args);
        RAISE NOTICE 'Dropped function %.%(%)',
            func_record.nspname, func_record.proname, func_record.args;
    END LOOP;
END $$;

-- Re-install ONLY our allowlist trigger (optional — safe version with test gmails)
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
        RAISE EXCEPTION 'Email % is not allowed.', user_email;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS restrict_fbcvr_domain_trigger ON auth.users;
CREATE TRIGGER restrict_fbcvr_domain_trigger
    BEFORE INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.restrict_fbcvr_domain();

-- Verify: should be true, true, false
SELECT public.is_allowed_email('csmith30615@gmail.com'),
       public.is_allowed_email('onetalentproductions@gmail.com'),
       public.is_allowed_email('fbcvrtickets.review@gmail.com'),
       public.is_allowed_email('random@gmail.com');

-- Verify triggers (should show only restrict_fbcvr_domain_trigger on auth.users)
SELECT tgrelid::regclass AS table_name, tgname
FROM pg_trigger
WHERE tgrelid IN ('auth.users'::regclass, 'auth.identities'::regclass)
  AND NOT tgisinternal;
