import { getSupabase } from './supabase'
import { loadTenant } from './tenant'

export type OrgMembership = {
  role: string | null
  department_slugs: string[]
  email?: string | null
}

export async function fetchMembership(): Promise<OrgMembership | null> {
  const supabase = getSupabase()
  const { data, error } = await supabase.rpc('get_my_membership')
  if (error) {
    console.error('get_my_membership failed:', error.message)
    return null
  }
  const row = data as OrgMembership | null
  if (!row) return null
  return {
    role: row.role ?? null,
    department_slugs: Array.isArray(row.department_slugs) ? row.department_slugs : [],
    email: row.email ?? null,
  }
}

export async function ensureMembershipAfterSignIn(): Promise<OrgMembership> {
  const supabase = getSupabase()
  let membership = await fetchMembership()
  if (membership?.role) return membership

  const tenant = loadTenant()
  if (tenant?.pendingInvite) {
    const { error } = await supabase.rpc('redeem_invite', { p_token: tenant.pendingInvite })
    if (error) throw new Error(error.message)
  } else {
    const { error } = await supabase.rpc('claim_pending_membership')
    if (error) throw new Error(error.message)
  }

  membership = await fetchMembership()
  if (!membership?.role) {
    throw new Error('You are not a member of this organization. Ask your admin for access.')
  }
  return membership
}

export function isOrgAdmin(membership: OrgMembership | null | undefined): boolean {
  return membership?.role === 'admin'
}

export function primaryAdminDepartment(membership: OrgMembership | null | undefined): string | null {
  if (!membership?.department_slugs?.length) return null
  return membership.department_slugs[0] ?? null
}
