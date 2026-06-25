-- Push notification device tokens + webhook setup
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS push_device_tokens (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform     TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios')),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, device_token)
);

CREATE INDEX IF NOT EXISTS idx_push_device_tokens_user_id ON push_device_tokens(user_id);

ALTER TABLE push_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own push tokens" ON push_device_tokens;
CREATE POLICY "Users manage own push tokens" ON push_device_tokens
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Service role (edge function) reads all tokens when sending notifications
DROP POLICY IF EXISTS "Service role reads push tokens" ON push_device_tokens;
CREATE POLICY "Service role reads push tokens" ON push_device_tokens
    FOR SELECT
    USING (auth.role() = 'service_role');

-- =============================================================================
-- AFTER RUNNING THIS SQL
-- =============================================================================
-- 1. Apple Developer → Identifiers → com.onetalentproductions.FBCVRTickets
--    Enable Push Notifications capability
-- 2. Create an APNs Auth Key (.p8) → note Key ID and Team ID
-- 3. Deploy edge function: supabase/functions/send-push
-- 4. Set secrets:
--      APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID=com.onetalentproductions.FBCVRTickets
--      APNS_PRIVATE_KEY (full .p8 contents)
--      APNS_USE_SANDBOX=true   (TestFlight/dev) or false (App Store production)
-- 5. Run supabase/push_webhooks.sql in SQL Editor (creates INSERT triggers → send-push)
--    Dashboard alternative: Integrations → Database Webhooks (same result)
-- 6. For App Store builds: set FBCVRTickets.entitlements aps-environment to "production"
--    and APNS_USE_SANDBOX=false. Use sandbox + development for local/TestFlight testing.
