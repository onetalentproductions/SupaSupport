-- Allow test Gmail accounts for development
-- Run this in Supabase SQL Editor if you already ran the original schema.sql

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

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN lower(auth.jwt() ->> 'email') IN (
        'austinsmith@fbcvr.com',
        'zack@fbcvr.com',
        'onetalentproductions@gmail.com'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

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

-- Verify: should return true, true, false
-- SELECT public.is_allowed_email('csmith30615@gmail.com'),
--        public.is_allowed_email('onetalentproductions@gmail.com'),
--        public.is_allowed_email('random@gmail.com');
