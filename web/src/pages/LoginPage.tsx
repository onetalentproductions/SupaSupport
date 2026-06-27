import { useState } from 'react'
import { Link, Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { PublicShell } from '../components/Layout'
import { appConfig } from '../lib/config'
import { clearTenant, loadTenant } from '../lib/tenant'
import { resetSupabaseClient } from '../lib/supabase'

export function LoginPage() {
  const { signIn, signInWithEmail } = useAuth()
  const [email, setEmail] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [info, setInfo] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const tenant = loadTenant()

  if (!tenant) return <Navigate to="/connect" replace />

  async function handleMagicLink() {
    setError(null)
    setInfo(null)
    setLoading(true)
    try {
      await signInWithEmail(email)
      setInfo('Check your email for a sign-in link.')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not send magic link')
    } finally {
      setLoading(false)
    }
  }

  async function handleGoogleSignIn() {
    setError(null)
    setInfo(null)
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
        <p className="muted">{appConfig.appName} — sign in to continue</p>

        <label className="field">
          <span>Work email</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            autoComplete="email"
          />
        </label>

        <button
          type="button"
          className="btn btn-primary btn-wide"
          onClick={handleMagicLink}
          disabled={loading || !email.trim()}
        >
          {loading ? 'Sending…' : 'Email me a sign-in link'}
        </button>

        <button
          type="button"
          className="btn btn-small btn-wide"
          style={{ marginTop: '0.5rem' }}
          onClick={handleGoogleSignIn}
          disabled={loading}
        >
          Sign in with Google
        </button>

        <button type="button" className="btn btn-ghost btn-wide" onClick={useDifferentOrg}>
          Use a different organization
        </button>

        {info && <p className="fine-print" style={{ color: '#14532d', fontWeight: 600 }}>{info}</p>}
        {error && <p className="error-text">{error}</p>}
        <p className="fine-print">
          By signing in you agree to our <Link to="/privacy">Privacy Policy</Link>.
        </p>
      </div>
    </PublicShell>
  )
}
