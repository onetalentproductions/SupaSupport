export type TenantConfig = {
  orgName: string
  supabaseUrl: string
  supabaseAnonKey: string
  mediaBucket: string
  pendingInvite?: string
}

const STORAGE_KEY = 'supasupport.tenant'

export function loadTenant(): TenantConfig | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? (JSON.parse(raw) as TenantConfig) : null
  } catch {
    return null
  }
}

export function saveTenant(config: TenantConfig) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(config))
}

export function clearTenant() {
  localStorage.removeItem(STORAGE_KEY)
}

export type ConnectPayload = {
  v: number
  name: string
  url: string
  key: string
  invite?: string
  bucket?: string
}

export function parseConnectPayload(raw: string): TenantConfig {
  const trimmed = raw.trim()
  const payload = JSON.parse(trimmed) as ConnectPayload
  if (payload.v !== 1) throw new Error('Unsupported connect payload version')
  if (!payload.url || !payload.key) throw new Error('Missing url or key')
  return {
    orgName: payload.name || 'Organization',
    supabaseUrl: payload.url.trim(),
    supabaseAnonKey: payload.key.trim(),
    mediaBucket: payload.bucket || 'ticket-media',
    pendingInvite: payload.invite,
  }
}

export function encodeConnectPayload(config: TenantConfig, invite?: string): string {
  return JSON.stringify({
    v: 1,
    name: config.orgName,
    url: config.supabaseUrl,
    key: config.supabaseAnonKey,
    invite,
    bucket: config.mediaBucket,
  })
}
