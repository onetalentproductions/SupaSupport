-- Push notification database webhooks (SQL alternative to Dashboard UI)
-- Run this in Supabase SQL Editor AFTER deploying the send-push edge function.
--
-- Uses the same mechanism as Dashboard → Integrations → Database Webhooks:
-- pg_net + supabase_functions.http_request with auto-generated INSERT payloads.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- New ticket → notify department admins
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS push_new_ticket ON public.tickets;
CREATE TRIGGER push_new_ticket
    AFTER INSERT ON public.tickets
    FOR EACH ROW
    EXECUTE FUNCTION supabase_functions.http_request(
        'https://atgrgtkbwfcxvibgkqla.supabase.co/functions/v1/send-push',
        'POST',
        '{"Content-Type":"application/json"}',
        '{}',
        '5000'
    );

-- ---------------------------------------------------------------------------
-- New message → notify ticket owner or department admins
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS push_new_message ON public.ticket_messages;
CREATE TRIGGER push_new_message
    AFTER INSERT ON public.ticket_messages
    FOR EACH ROW
    EXECUTE FUNCTION supabase_functions.http_request(
        'https://atgrgtkbwfcxvibgkqla.supabase.co/functions/v1/send-push',
        'POST',
        '{"Content-Type":"application/json"}',
        '{}',
        '5000'
    );

-- ---------------------------------------------------------------------------
-- Verify triggers exist
-- ---------------------------------------------------------------------------
-- SELECT trigger_name, event_object_table, action_timing, event_manipulation
-- FROM information_schema.triggers
-- WHERE trigger_name IN ('push_new_ticket', 'push_new_message');
