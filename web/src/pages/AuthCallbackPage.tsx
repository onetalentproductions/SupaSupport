import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { handleAuthCallback } from '../lib/auth'
import { ensureMembershipAfterSignIn } from '../lib/org'
import { useAuth } from '../context/AuthContext'
import { PublicShell } from '../components/Layout'

export function AuthCallbackPage() {
  const navigate = useNavigate()
  const { refresh } = useAuth()
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    handleAuthCallback()
      .then(async () => {
        await ensureMembershipAfterSignIn()
        await refresh()
        navigate('/tickets', { replace: true })
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : 'Sign-in failed')
      })
  }, [navigate, refresh])

  return (
    <PublicShell>
      <div className="login-card">
        {!error ? (
          <>
            <div className="spinner" />
            <p>Completing sign-in…</p>
          </>
        ) : (
          <>
            <h1>Sign-in failed</h1>
            <p className="error-text">{error}</p>
            <Link to="/login" className="btn btn-primary btn-wide">
              Back to sign in
            </Link>
          </>
        )}
      </div>
    </PublicShell>
  )
}
