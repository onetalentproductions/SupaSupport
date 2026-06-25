import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts"

const MEDIA_ADMIN_EMAILS = [
  "austinsmith@fbcvr.com",
  "zack@fbcvr.com",
  "onetalentproductions@gmail.com",
]

const FACILITIES_ADMIN_EMAILS = [
  "sonya@fbcvr.com",
  "hunter@fbcvr.com",
  "onetalentproductions@gmail.com",
]

type PushPayload = {
  type: "new_ticket" | "new_message"
  record: Record<string, unknown>
}

function adminEmailsForDepartment(department: string | undefined): string[] {
  if (department === "facilities") return FACILITIES_ADMIN_EMAILS
  return MEDIA_ADMIN_EMAILS
}

function normalizePayload(raw: unknown): PushPayload | null {
  if (!raw || typeof raw !== "object") return null
  const obj = raw as Record<string, unknown>

  if (obj.type === "new_ticket" || obj.type === "new_message") {
    return { type: obj.type, record: obj.record as Record<string, unknown> }
  }

  // Supabase Database Webhook format
  if (obj.type === "INSERT" && obj.record && typeof obj.record === "object") {
    const table = String(obj.table ?? "")
    const record = obj.record as Record<string, unknown>
    if (table === "tickets") return { type: "new_ticket", record }
    if (table === "ticket_messages") return { type: "new_message", record }
  }

  return null
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 })
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  let rawBody: unknown
  try {
    rawBody = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400 })
  }

  const payload = normalizePayload(rawBody)
  if (!payload) {
    return new Response(JSON.stringify({ error: "Unrecognized payload" }), { status: 400 })
  }

  const apnsJWT = await createApnsJWT()
  const useSandbox = Deno.env.get("APNS_USE_SANDBOX") === "true"
  const apnsHost = useSandbox
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com"

  let tokens: string[] = []
  let title = "FBCVR Tickets"
  let body = "You have an update"

  if (payload.type === "new_ticket") {
    const userEmail = String(payload.record.user_email ?? "")
    const ticketTitle = String(payload.record.title ?? "New ticket")
    const department = String(payload.record.department ?? "media")
    title = "New ticket submitted"
    body = `${userEmail}: ${ticketTitle}`
    tokens = await fetchTokensForEmails(
      supabase,
      adminEmailsForDepartment(department)
    )
  } else if (payload.type === "new_message") {
    const isAdmin = Boolean(payload.record.is_admin)
    const ticketId = String(payload.record.ticket_id ?? "")
    const preview = String(payload.record.body ?? "New reply").slice(0, 120)

    if (isAdmin) {
      title = "Reply on your ticket"
      body = preview
      tokens = await fetchTokensForTicketOwner(supabase, ticketId)
    } else {
      title = "New ticket reply"
      body = preview
      const department = await fetchTicketDepartment(supabase, ticketId)
      tokens = await fetchTokensForEmails(
        supabase,
        adminEmailsForDepartment(department)
      )
    }
  }

  const results = await Promise.all(
    tokens.map((deviceToken) =>
      sendApns(apnsHost, apnsJWT, deviceToken, title, body, payload)
    )
  )

  return new Response(
    JSON.stringify({ sent: results.filter(Boolean).length, total: tokens.length }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  )
})

async function createApnsJWT(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID")
  const teamId = Deno.env.get("APNS_TEAM_ID")
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY")

  if (!keyId || !teamId || !privateKey) {
    throw new Error("Missing APNS_KEY_ID, APNS_TEAM_ID, or APNS_PRIVATE_KEY")
  }

  const key = await jose.importPKCS8(privateKey.replace(/\\n/g, "\n"), "ES256")
  return await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(key)
}

async function sendApns(
  host: string,
  jwt: string,
  deviceToken: string,
  title: string,
  body: string,
  payload: PushPayload
): Promise<boolean> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.onetalentproductions.FBCVRTickets"

  const response = await fetch(`${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: { title, body },
        sound: "default",
      },
      type: payload.type,
      record: payload.record,
    }),
  })

  if (!response.ok) {
    const text = await response.text()
    console.error(`APNs error for ${deviceToken}: ${response.status} ${text}`)
    return false
  }

  return true
}

async function fetchTokensForEmails(
  supabase: ReturnType<typeof createClient>,
  emails: string[]
): Promise<string[]> {
  const normalized = emails.map((e) => e.toLowerCase())
  const { data: users, error: usersError } = await supabase.auth.admin.listUsers()

  if (usersError) {
    console.error(usersError)
    return []
  }

  const userIds = users.users
    .filter((u) => u.email && normalized.includes(u.email.toLowerCase()))
    .map((u) => u.id)

  if (userIds.length === 0) return []

  const { data, error } = await supabase
    .from("push_device_tokens")
    .select("device_token")
    .in("user_id", userIds)

  if (error) {
    console.error(error)
    return []
  }

  return [...new Set((data ?? []).map((row) => row.device_token as string))]
}

async function fetchTicketDepartment(
  supabase: ReturnType<typeof createClient>,
  ticketId: string
): Promise<string> {
  const { data: ticket, error } = await supabase
    .from("tickets")
    .select("department")
    .eq("id", ticketId)
    .maybeSingle()

  if (error || !ticket) {
    console.error(error)
    return "media"
  }

  return String(ticket.department ?? "media")
}

async function fetchTokensForTicketOwner(
  supabase: ReturnType<typeof createClient>,
  ticketId: string
): Promise<string[]> {
  const { data: ticket, error: ticketError } = await supabase
    .from("tickets")
    .select("user_id")
    .eq("id", ticketId)
    .maybeSingle()

  if (ticketError || !ticket) {
    console.error(ticketError)
    return []
  }

  const { data, error } = await supabase
    .from("push_device_tokens")
    .select("device_token")
    .eq("user_id", ticket.user_id)

  if (error) {
    console.error(error)
    return []
  }

  return (data ?? []).map((row) => row.device_token as string)
}
