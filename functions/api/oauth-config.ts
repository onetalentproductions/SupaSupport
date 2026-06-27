type Env = {
  GOOGLE_OAUTH_CLIENT_ID?: string
  GOOGLE_OAUTH_CLIENT_SECRET?: string
  APPLE_SERVICES_ID?: string
  APPLE_TEAM_ID?: string
  APPLE_KEY_ID?: string
  APPLE_PRIVATE_KEY?: string
}

function isValidSupabaseUrl(url: string): boolean {
  try {
    const parsed = new URL(url.trim())
    return parsed.protocol === 'https:' && parsed.hostname.endsWith('.supabase.co')
  } catch {
    return false
  }
}

function json(data: unknown, status = 200) {
  return Response.json(data, {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  })
}

export const onRequestPost: PagesFunction<Env> = async (context) => {
  let body: { supabaseUrl?: string }
  try {
    body = await context.request.json()
  } catch {
    return json({ error: 'Invalid JSON body' }, 400)
  }

  const supabaseUrl = body.supabaseUrl?.trim().replace(/\/$/, '') ?? ''
  if (!isValidSupabaseUrl(supabaseUrl)) {
    return json({ error: 'Enter a valid https://xxxx.supabase.co project URL first.' }, 400)
  }

  const googleClientId = context.env.GOOGLE_OAUTH_CLIENT_ID
  const googleClientSecret = context.env.GOOGLE_OAUTH_CLIENT_SECRET

  if (!googleClientId || !googleClientSecret) {
    return json(
      {
        error:
          'SupaSupport OAuth credentials are not configured on the server yet. Use email magic link sign-in for now.',
      },
      503
    )
  }

  const appleConfigured = Boolean(
    context.env.APPLE_SERVICES_ID &&
      context.env.APPLE_TEAM_ID &&
      context.env.APPLE_KEY_ID &&
      context.env.APPLE_PRIVATE_KEY
  )

  return json({
    supabaseUrl,
    google: {
      clientId: googleClientId,
      clientSecret: googleClientSecret,
    },
    apple: appleConfigured
      ? {
          servicesId: context.env.APPLE_SERVICES_ID,
          teamId: context.env.APPLE_TEAM_ID,
          keyId: context.env.APPLE_KEY_ID,
          privateKey: context.env.APPLE_PRIVATE_KEY,
        }
      : null,
    webRedirectUrl: `${supabaseUrl}/auth/v1/callback`,
    notes: {
      ios:
        'The SupaSupport iOS app uses native Google/Apple sign-in. Paste the values below into Supabase → Authentication → Providers. No Google Cloud account is required on your side.',
      web:
        'For the website, use Email magic link (above). Web Google OAuth also needs your project callback URL registered in our Google Cloud console — email magic link avoids that.',
    },
  })
}
