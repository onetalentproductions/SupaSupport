import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { appConfig } from '../lib/config'
import { parseConnectPayload, saveTenant } from '../lib/tenant'
import { resetSupabaseClient } from '../lib/supabase'
import { PublicShell } from '../components/Layout'

export function ConnectPage() {
  const navigate = useNavigate()
  const [payload, setPayload] = useState('')
  const [error, setError] = useState<string | null>(null)

  function handleConnect() {
    setError(null)
    try {
      const tenant = parseConnectPayload(payload)
      saveTenant(tenant)
      resetSupabaseClient()
      navigate('/login')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Invalid connection payload')
    }
  }

  return (
    <PublicShell>
      <div className="login-card">
        <div className="login-logo">SS</div>
        <h1>{appConfig.appName}</h1>
        <p className="muted">Paste the connection JSON or QR payload from your admin.</p>
        <textarea
          value={payload}
          onChange={(e) => setPayload(e.target.value)}
          rows={8}
          placeholder='{"v":1,"name":"My Org","url":"https://....supabase.co","key":"..."}'
          style={{ width: '100%', fontFamily: 'monospace', fontSize: 12 }}
        />
        <button type="button" className="btn btn-primary btn-wide" onClick={handleConnect} disabled={!payload.trim()}>
          Connect
        </button>
        {error && <p className="error-text">{error}</p>}
        <p className="fine-print">
          Setting up a new organization? <Link to="/setup">Create server →</Link>
        </p>
        <p className="fine-print">
          <Link to="/">← Back to home</Link>
        </p>
      </div>
    </PublicShell>
  )
}
