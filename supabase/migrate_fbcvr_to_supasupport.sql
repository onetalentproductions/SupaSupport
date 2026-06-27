-- Migrate an existing FBCVR Supabase project toward SupaSupport schema.
-- Run bootstrap.sql after this file (bootstrap now drops legacy functions/policies).

CREATE TABLE IF NOT EXISTS org_settings (
    id              INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    org_name        TEXT NOT NULL DEFAULT 'FBCVR',
    access_mode     TEXT NOT NULL DEFAULT 'invite_only'
                    CHECK (access_mode IN ('invite_only', 'domain', 'open')),
    allowed_domain  TEXT,
    schema_version  INT NOT NULL DEFAULT 1,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO org_settings (org_name, access_mode) VALUES ('FBCVR', 'invite_only')
ON CONFLICT (id) DO UPDATE SET org_name = EXCLUDED.org_name;

CREATE TABLE IF NOT EXISTS departments (
    slug        TEXT PRIMARY KEY,
    label       TEXT NOT NULL,
    sort_order  INT NOT NULL DEFAULT 0,
    color_hex   TEXT
);

INSERT INTO departments (slug, label, sort_order, color_hex) VALUES
    ('facilities', 'Facilities', 0, '#D16B14'),
    ('media', 'Media', 1, '#7338C7')
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE IF NOT EXISTS org_members (
    user_id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email             TEXT,
    role              TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    department_slugs  TEXT[] NOT NULL DEFAULT '{}',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pending_members (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email             TEXT,
    role              TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    department_slugs  TEXT[] NOT NULL DEFAULT '{}',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    claimed_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    claimed_at        TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS invites (
    token             TEXT PRIMARY KEY,
    role              TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    department_slugs  TEXT[] NOT NULL DEFAULT '{}',
    email             TEXT,
    created_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    expires_at        TIMESTAMPTZ,
    redeemed_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    redeemed_at       TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Legacy analytics RPC (see bootstrap.sql for replacement)
DROP FUNCTION IF EXISTS get_department_completion_counts();

INSERT INTO org_members (user_id, email, role, department_slugs)
SELECT u.id, u.email, 'admin', ARRAY['media','facilities']
FROM auth.users u
WHERE lower(u.email) IN (
    'austinsmith@fbcvr.com',
    'zack@fbcvr.com',
    'sonya@fbcvr.com',
    'hunter@fbcvr.com',
    'onetalentproductions@gmail.com'
)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO org_members (user_id, email, role, department_slugs)
SELECT DISTINCT t.user_id, t.user_email, 'user', ARRAY['facilities']
FROM tickets t
WHERE NOT EXISTS (SELECT 1 FROM org_members m WHERE m.user_id = t.user_id)
ON CONFLICT (user_id) DO NOTHING;

ALTER TABLE org_settings ADD COLUMN IF NOT EXISTS icon_key TEXT;
ALTER TABLE org_settings ADD COLUMN IF NOT EXISTS logo_url TEXT;
UPDATE org_settings SET org_name = 'FBCVR', icon_key = 'fbcvr' WHERE id = 1;

-- Next step: run supabase/bootstrap.sql in the SQL Editor (creates RPC + RLS).
