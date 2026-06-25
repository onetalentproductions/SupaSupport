-- =============================================================================
-- TEMPORARY: Open sign-in for Apple App Review (Hide My Email / any provider)
-- =============================================================================
-- Run in Supabase SQL Editor BEFORE review testing.
-- After review, run: supabase/app_store_restore_auth.sql
--
-- ALSO do this in the Dashboard (if enabled):
--   Authentication → Hooks → "Before user created"
--   Either DISABLE the hook, OR leave it ON — this script updates
--   public.hook_before_user_created to allow everyone.
--
-- IMPORTANT — run app_store_open_auth.sql on Supabase too so new accounts
-- are not rejected server-side. Restore both when review is done:
--   • supabase/app_store_restore_auth.sql
--   • revert client isAllowedEmail in AppConfig.swift + web config.ts
-- =============================================================================

-- Allow any non-empty email (including Apple private relay)
CREATE OR REPLACE FUNCTION public.is_allowed_email(email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF email IS NULL OR trim(email) = '' THEN
        RETURN true;
    END IF;
    RETURN true;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Stop blocking new auth.users rows
CREATE OR REPLACE FUNCTION public.restrict_fbcvr_domain()
RETURNS TRIGGER AS $$
BEGIN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS restrict_fbcvr_domain_trigger ON auth.users;
CREATE TRIGGER restrict_fbcvr_domain_trigger
    BEFORE INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.restrict_fbcvr_domain();

-- Allow all sign-ups via Auth Hook (if hook is enabled in Dashboard)
CREATE OR REPLACE FUNCTION public.hook_before_user_created(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN '{}'::jsonb;
END;
$$;

GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) FROM authenticated, anon, public;

-- Verify — all should return true
SELECT public.is_allowed_email('reviewer@privaterelay.appleid.com') AS apple_relay_ok,
       public.is_allowed_email('random@gmail.com') AS random_ok,
       public.is_allowed_email('austinsmith@fbcvr.com') AS fbcvr_ok;
