import { getSupabase } from './supabase'
import { userDisplayEmail } from './config'

export async function signInWithGoogle() {
  const supabase = getSupabase()
  const redirectTo = `${window.location.origin}/auth/callback`
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo },
  })
  if (error) throw error
}

export async function signInWithMagicLink(email: string) {
  const supabase = getSupabase()
  const redirectTo = `${window.location.origin}/auth/callback`
  const { error } = await supabase.auth.signInWithOtp({
    email: email.trim(),
    options: { emailRedirectTo: redirectTo },
  })
  if (error) throw error
}

export async function signOut() {
  const supabase = getSupabase()
  const { error } = await supabase.auth.signOut()
  if (error) throw error
}

export async function getSessionUser() {
  const supabase = getSupabase()
  const { data, error } = await supabase.auth.getSession()
  if (error) throw error
  const session = data.session
  if (!session) return null

  return { session, email: userDisplayEmail(session.user) }
}

export async function handleAuthCallback() {
  const supabase = getSupabase()
  const { data, error } = await supabase.auth.getSession()
  if (error) throw error
  if (!data.session) {
    throw new Error('Sign-in did not complete. Try again.')
  }

  return { session: data.session, email: userDisplayEmail(data.session.user) }
}
