import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { Session } from '@supabase/supabase-js'
import { getSupabase } from '../lib/supabase'
import { getSessionUser, signInWithGoogle, signOut } from '../lib/auth'
import { isAdminEmail, adminDepartmentForEmail } from '../lib/config'
import { loadTenant } from '../lib/tenant'

interface AuthState {
  session: Session | null
  email: string | null
  isAdmin: boolean
  adminDepartment: string | null
  loading: boolean
  signIn: () => Promise<void>
  signOut: () => Promise<void>
  refresh: () => Promise<void>
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [email, setEmail] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    if (!loadTenant()) {
      setSession(null)
      setEmail(null)
      return
    }
    const result = await getSessionUser()
    if (result) {
      setSession(result.session)
      setEmail(result.email)
    } else {
      setSession(null)
      setEmail(null)
    }
  }, [])

  useEffect(() => {
    refresh().finally(() => setLoading(false))

    if (!loadTenant()) return

    const supabase = getSupabase()
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async () => {
      await refresh()
    })

    return () => subscription.unsubscribe()
  }, [refresh])

  const value = useMemo<AuthState>(
    () => ({
      session,
      email,
      isAdmin: isAdminEmail(email),
      adminDepartment: adminDepartmentForEmail(email),
      loading,
      signIn: signInWithGoogle,
      signOut,
      refresh,
    }),
    [session, email, loading, refresh]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
