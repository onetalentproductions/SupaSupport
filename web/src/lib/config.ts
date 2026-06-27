import type { User } from '@supabase/supabase-js'

export const appConfig = {
  appName: 'SupaSupport',
  siteUrl: 'https://supasupport.net',
  tagline: 'Helpdesk tickets on your own Supabase — private to your team.',
  supportEmail: 'support@supasupport.net',
  /** Public Google OAuth client ID — safe to show; secret is provisioned per org by support. */
  sharedGoogleClientId: import.meta.env.VITE_SHARED_GOOGLE_CLIENT_ID ?? '',
} as const

export function validateConfig(): string | null {
  return null
}

export function userDisplayEmail(user: User): string {
  const candidates = [
    user.email,
    typeof user.user_metadata?.email === 'string' ? user.user_metadata.email : null,
    typeof user.identities?.[0]?.identity_data?.email === 'string'
      ? user.identities[0].identity_data.email
      : null,
  ]
  for (const candidate of candidates) {
    if (candidate?.trim()) return candidate.toLowerCase().trim()
  }
  return `${user.id}@user.local`
}
