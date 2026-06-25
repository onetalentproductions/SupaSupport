-- Admin email notification via Supabase Database Webhook or Edge Function
-- Option A: Supabase Dashboard > Database > Webhooks
--   Table: tickets, Event: INSERT
--   Target: Edge Function or external email service (SendGrid, Resend, etc.)
--
-- Option B: Deploy this Edge Function (supabase/functions/notify-admins/index.ts)

/*
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const ADMIN_EMAILS = ["austinsmith@fbcvr.com", "zack@fbcvr.com"]

Deno.serve(async (req) => {
  const { record } = await req.json()
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  // Send email via your provider, or use Supabase's built-in auth email
  for (const email of ADMIN_EMAILS) {
    console.log(`New ticket from ${record.user_email}: ${record.title}`)
    // await sendEmail(email, `New ticket: ${record.title}`, ...)
  }

  return new Response(JSON.stringify({ ok: true }), { status: 200 })
})
*/
