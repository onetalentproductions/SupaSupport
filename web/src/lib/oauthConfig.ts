export type OAuthConfigResponse = {
  supabaseUrl: string
  google: {
    clientId: string
    clientSecret: string
  }
  apple: {
    servicesId?: string
    teamId?: string
    keyId?: string
    privateKey?: string
  } | null
  webRedirectUrl: string
  notes: {
    ios: string
    web: string
  }
}

export async function fetchOAuthConfig(supabaseUrl: string): Promise<OAuthConfigResponse> {
  const response = await fetch('/api/oauth-config', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ supabaseUrl: supabaseUrl.trim().replace(/\/$/, '') }),
  })

  const data = (await response.json()) as OAuthConfigResponse & { error?: string }
  if (!response.ok) {
    throw new Error(data.error ?? 'Could not load sign-in credentials')
  }
  return data
}
