import { createClient, SupabaseClient } from '@supabase/supabase-js'
import { loadTenant } from './tenant'

let cached: { key: string; client: SupabaseClient } | null = null

export function getSupabase(): SupabaseClient {
  const tenant = loadTenant()
  if (!tenant) {
    throw new Error('Connect to an organization first.')
  }
  const cacheKey = `${tenant.supabaseUrl}:${tenant.supabaseAnonKey}`
  if (cached?.key === cacheKey) return cached.client
  const client = createClient(tenant.supabaseUrl, tenant.supabaseAnonKey)
  cached = { key: cacheKey, client }
  return client
}

export function resetSupabaseClient() {
  cached = null
}
