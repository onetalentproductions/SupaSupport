import type { User } from '@supabase/supabase-js'
import { appConfig } from './config'

export { appConfig }

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

// Web admin detection will use org_members RPC in a follow-up pass.
export function isAdminEmail(_email: string | null | undefined): boolean {
  return false
}

export function adminDepartmentForEmail(_email: string | null | undefined): string | null {
  return null
}
