import { useState } from 'react'
import { Link, Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { PublicShell } from '../components/Layout'
import { appConfig } from '../lib/config'
import { clearTenant, loadTenant } from '../lib/tenant'
import { resetSupabaseClient } from '../lib/supabase'

export function LoginPage() {
  const { signIn } = useAuth()
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const tenant = loadTenant()

  if (!tenant) return <Navigate to="/connect" replace />

  async function handleSignIn() {
    setError(null)
    setLoading(true)
    try {
      await signIn()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign-in failed')
      setLoading(false)
    }
  }

  function useDifferentOrg() {
    clearTenant()
    resetSupabaseClient()
    window.location.href = '/connect'
  }

  return (
    <PublicShell>
      <div className="login-card">
        <div className="login-logo">SS</div>
        <h1>{tenant.orgName}</h1>
        <p className="muted">{appConfig.appName} — sign in with Google</p>
        <button type="button" className="btn btn-primary btn-wide" onClick={handleSignIn} disabled={loading}>
          {loading ? 'Redirecting…' : 'Sign in with Google'}
        </button>
        <button type="button" className="btn btn-ghost btn-wide" onClick={useDifferentOrg}>
          Use a different organization
        </button>
        {error && <p className="error-text">{error}</p>}
        <p className="fine-print">
          By signing in you agree to our <Link to="/privacy">Privacy Policy</Link>.
        </p>
      </div>
    </PublicShell>
  )
}
