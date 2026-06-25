-- =============================================================================
-- RESTORE: Normal @fbcvr.com + approved test account sign-in restrictions
-- =============================================================================
-- Run in Supabase SQL Editor AFTER Apple review testing is complete.
--
-- Note: The iOS/web apps currently accept any email on the client. Supabase
-- restore is enough to block new sign-ups. To also restore the in-app
-- allowlist, revert isAllowedEmail() in AppConfig.swift and web config.ts,
-- then rebuild iOS and redeploy web.
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

DROP TRIGGER IF EXISTS restrict_fbcvr_domain_trigger ON auth.users;
CREATE TRIGGER restrict_fbcvr_domain_trigger
    BEFORE INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.restrict_fbcvr_domain();

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

GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) FROM authenticated, anon, public;

-- Verify — fbcvr/review true, random false
SELECT public.is_allowed_email('austinsmith@fbcvr.com') AS fbcvr_ok,
       public.is_allowed_email('fbcvrtickets.review@gmail.com') AS review_ok,
       public.is_allowed_email('random@gmail.com') AS random_blocked;
