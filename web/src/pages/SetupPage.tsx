import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { appConfig } from '../lib/config'
import { encodeConnectPayload, saveTenant } from '../lib/tenant'
import { resetSupabaseClient } from '../lib/supabase'
import { buildFullBootstrapSql, type SetupWizardInput } from '../lib/setupSql'
import { PublicShell } from '../components/Layout'
import { CopyButton } from '../components/CopyButton'
import { QrImage } from '../components/QrImage'
import { fetchOAuthConfig, type OAuthConfigResponse } from '../lib/oauthConfig'

const STEPS = [
  'Organization',
  'Create Supabase',
  'Run SQL',
  'Storage',
  'Sign-in',
  'Connect app',
] as const

type AccessMode = SetupWizardInput['accessMode']

export function SetupPage() {
  const navigate = useNavigate()
  const [step, setStep] = useState(0)

  const [orgName, setOrgName] = useState('')
  const [adminEmail, setAdminEmail] = useState('')
  const [departments, setDepartments] = useState('Facilities\nMedia')
  const [accessMode, setAccessMode] = useState<AccessMode>('invite_only')
  const [allowedDomain, setAllowedDomain] = useState('@example.com')

  const [supabaseUrl, setSupabaseUrl] = useState('')
  const [anonKey, setAnonKey] = useState('')
  const [oauthConfig, setOauthConfig] = useState<OAuthConfigResponse | null>(null)
  const [oauthError, setOauthError] = useState<string | null>(null)
  const [oauthLoading, setOauthLoading] = useState(false)

  const departmentLines = useMemo(
    () =>
      departments
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean),
    [departments]
  )

  const wizardInput: SetupWizardInput | null = useMemo(() => {
    if (!orgName.trim() || !adminEmail.trim() || departmentLines.length === 0) return null
    return {
      orgName: orgName.trim(),
      adminEmail: adminEmail.trim(),
      departments: departmentLines,
      accessMode,
      allowedDomain: accessMode === 'domain' ? allowedDomain : undefined,
    }
  }, [orgName, adminEmail, departmentLines, accessMode, allowedDomain])

  const fullSql = useMemo(
    () => (wizardInput ? buildFullBootstrapSql(wizardInput) : ''),
    [wizardInput]
  )

  const connectJson = useMemo(() => {
    if (!wizardInput || !supabaseUrl.trim() || !anonKey.trim()) return ''
    return encodeConnectPayload({
      orgName: wizardInput.orgName,
      supabaseUrl: supabaseUrl.trim(),
      supabaseAnonKey: anonKey.trim(),
      mediaBucket: 'ticket-media',
    })
  }, [wizardInput, supabaseUrl, anonKey])

  const iosDeepLink = useMemo(() => {
    if (!wizardInput || !supabaseUrl.trim() || !anonKey.trim()) return ''
    const params = new URLSearchParams({
      v: '1',
      name: wizardInput.orgName,
      url: supabaseUrl.trim(),
      key: anonKey.trim(),
      bucket: 'ticket-media',
    })
    return `supasupport://connect?${params.toString()}`
  }, [wizardInput, supabaseUrl, anonKey])

  const step1Valid = Boolean(wizardInput)
  const step2Valid = supabaseUrl.trim().startsWith('https://') && supabaseUrl.includes('supabase.co')

  function goNext() {
    setStep((s) => Math.min(s + 1, STEPS.length - 1))
  }

  function goBack() {
    setStep((s) => Math.max(s - 1, 0))
  }

  function connectOnWeb() {
    if (!wizardInput || !connectJson) return
    saveTenant({
      orgName: wizardInput.orgName,
      supabaseUrl: supabaseUrl.trim(),
      supabaseAnonKey: anonKey.trim(),
      mediaBucket: 'ticket-media',
    })
    resetSupabaseClient()
    navigate('/login')
  }

  async function loadOAuthCredentials() {
    setOauthError(null)
    setOauthLoading(true)
    setOauthConfig(null)
    try {
      const config = await fetchOAuthConfig(supabaseUrl)
      setOauthConfig(config)
    } catch (err) {
      setOauthError(err instanceof Error ? err.message : 'Could not load credentials')
    } finally {
      setOauthLoading(false)
    }
  }

  return (
    <PublicShell>
      <div className="wizard-page">
        <div className="wizard-header">
          <Link to="/" className="wizard-back">
            ← {appConfig.appName}
          </Link>
          <h1>Create your server</h1>
          <p className="muted">Step {step + 1} of {STEPS.length}: {STEPS[step]}</p>
          <div className="wizard-progress" aria-hidden>
            {STEPS.map((label, index) => (
              <span
                key={label}
                className={`wizard-dot${index <= step ? ' active' : ''}${index === step ? ' current' : ''}`}
              />
            ))}
          </div>
        </div>

        <div className="wizard-body card">
          {step === 0 && (
            <>
              <h2>Organization details</h2>
              <p className="muted">We use this to customize the SQL script and connect payload.</p>

              <label className="field">
                <span>Organization name</span>
                <input value={orgName} onChange={(e) => setOrgName(e.target.value)} placeholder="Acme Church" />
              </label>

              <label className="field">
                <span>First admin email</span>
                <input
                  type="email"
                  value={adminEmail}
                  onChange={(e) => setAdminEmail(e.target.value)}
                  placeholder="you@example.com"
                />
                <span className="field-hint">This person becomes admin on first sign-in.</span>
              </label>

              <label className="field">
                <span>Departments (one per line)</span>
                <textarea
                  value={departments}
                  onChange={(e) => setDepartments(e.target.value)}
                  rows={4}
                  placeholder={'Facilities\nMedia'}
                />
              </label>

              <label className="field">
                <span>Who can sign in?</span>
                <select value={accessMode} onChange={(e) => setAccessMode(e.target.value as AccessMode)}>
                  <option value="invite_only">Pre-approved emails only (recommended)</option>
                  <option value="domain">Anyone with an email domain</option>
                  <option value="open">Anyone who can sign in with Google/Apple</option>
                </select>
              </label>

              {accessMode === 'domain' && (
                <label className="field">
                  <span>Allowed domain</span>
                  <input
                    value={allowedDomain}
                    onChange={(e) => setAllowedDomain(e.target.value)}
                    placeholder="@yourorg.com"
                  />
                </label>
              )}

              <div className="wizard-nav">
                <span />
                <button type="button" className="btn btn-primary" disabled={!step1Valid} onClick={goNext}>
                  Next →
                </button>
              </div>
            </>
          )}

          {step === 1 && (
            <>
              <h2>Create a Supabase project</h2>
              <ol className="instruction-list">
                <li>
                  Go to{' '}
                  <a href="https://supabase.com/dashboard" target="_blank" rel="noreferrer">
                    supabase.com/dashboard
                  </a>{' '}
                  and sign in (free tier is fine).
                </li>
                <li>
                  Click <strong>New project</strong>, pick a name and database password, choose a region
                  close to your team.
                </li>
                <li>Wait until the project finishes provisioning (1–2 minutes).</li>
                <li>
                  Open <strong>Project Settings → API</strong> and copy your <strong>Project URL</strong>{' '}
                  below.
                </li>
              </ol>

              <label className="field">
                <span>Supabase Project URL</span>
                <input
                  value={supabaseUrl}
                  onChange={(e) => setSupabaseUrl(e.target.value)}
                  placeholder="https://xxxxx.supabase.co"
                />
                <span className="field-hint">You will need the anon key on the last step.</span>
              </label>

              <div className="wizard-nav">
                <button type="button" className="btn-back" onClick={goBack}>
                  ← Back
                </button>
                <button type="button" className="btn btn-primary" disabled={!step2Valid} onClick={goNext}>
                  Next →
                </button>
              </div>
            </>
          )}

          {step === 2 && (
            <>
              <h2>Run the setup SQL</h2>
              <p className="muted">
                In Supabase, open <strong>SQL Editor → New query</strong>, paste everything below, and
                click <strong>Run</strong>. This creates tables, security rules, and your admin invite.
              </p>
              <div className="copy-row">
                <CopyButton text={fullSql} label="Copy full SQL" />
                <span className="fine-print">{fullSql.split('\n').length.toLocaleString()} lines</span>
              </div>
              <textarea
                readOnly
                className="code-block"
                value={fullSql}
                rows={16}
                spellCheck={false}
              />
              <p className="fine-print">
                Only paste the <strong>anon / publishable</strong> key later — never the service role key.
              </p>
              <div className="wizard-nav">
                <button type="button" className="btn-back" onClick={goBack}>
                  ← Back
                </button>
                <button type="button" className="btn btn-primary" onClick={goNext}>
                  SQL ran successfully →
                </button>
              </div>
            </>
          )}

          {step === 3 && (
            <>
              <h2>Create storage bucket</h2>
              <ol className="instruction-list">
                <li>
                  In Supabase, open <strong>Storage</strong> from the left sidebar.
                </li>
                <li>
                  Click <strong>New bucket</strong>, name it exactly{' '}
                  <code>ticket-media</code>.
                </li>
                <li>
                  For a small private team, you can leave it non-public — the app uploads using
                  authenticated requests.
                </li>
              </ol>
              <div className="wizard-nav">
                <button type="button" className="btn-back" onClick={goBack}>
                  ← Back
                </button>
                <button type="button" className="btn btn-primary" onClick={goNext}>
                  Bucket created →
                </button>
              </div>
            </>
          )}

          {step === 4 && (
            <>
              <h2>Enable sign-in</h2>
              <p className="muted">
                You do <strong>not</strong> need your own Google Cloud or Apple Developer account for
                basic setup. Everything below happens inside Supabase.
              </p>

              <div className="info-callout">
                <h3>Recommended: Email magic link</h3>
                <ol className="instruction-list" style={{ marginBottom: 0 }}>
                  <li>
                    Supabase → <strong>Authentication → Providers → Email</strong> → enable Email.
                  </li>
                  <li>
                    Supabase → <strong>Authentication → URL Configuration</strong>:
                    <ul>
                      <li>
                        Site URL: <code>{appConfig.siteUrl}</code>
                      </li>
                      <li>
                        Redirect URLs: add <code>{appConfig.siteUrl}/auth/callback</code>
                      </li>
                    </ul>
                  </li>
                  <li>
                    Sign in on the web with the admin email you entered in step 1 — SupaSupport sends a
                    one-time link to your inbox.
                  </li>
                </ol>
              </div>

              <div className="info-callout info-callout-muted">
                <h3>SupaSupport mobile app (Google / Apple)</h3>
                <p style={{ margin: '0 0 0.75rem' }}>
                  Your team does <strong>not</strong> create a Google Cloud or Apple Developer account.
                  SupaSupport provides shared sign-in credentials — paste them into Supabase in one step.
                </p>

                <button
                  type="button"
                  className="btn btn-primary"
                  disabled={!step2Valid || oauthLoading}
                  onClick={loadOAuthCredentials}
                >
                  {oauthLoading ? 'Loading…' : 'Get sign-in credentials'}
                </button>

                {oauthError && <p className="error-text">{oauthError}</p>}

                {oauthConfig && (
                  <div style={{ marginTop: '1rem' }}>
                    <p className="fine-print">{oauthConfig.notes.ios}</p>
                    <p className="fine-print">{oauthConfig.notes.web}</p>

                    <h4 style={{ marginBottom: '0.35rem' }}>Supabase → Authentication → Google</h4>
                    <ol className="instruction-list">
                      <li>Enable Google.</li>
                      <li>
                        Client ID: <code>{oauthConfig.google.clientId}</code>{' '}
                        <CopyButton text={oauthConfig.google.clientId} label="Copy ID" />
                      </li>
                      <li>
                        Client Secret: <CopyButton text={oauthConfig.google.clientSecret} label="Copy secret" />
                      </li>
                      <li>Save.</li>
                    </ol>

                    {oauthConfig.apple && (
                      <>
                        <h4 style={{ marginBottom: '0.35rem' }}>Supabase → Authentication → Apple</h4>
                        <ol className="instruction-list">
                          <li>Enable Apple.</li>
                          <li>
                            Services ID: <code>{oauthConfig.apple.servicesId}</code>{' '}
                            <CopyButton text={oauthConfig.apple.servicesId ?? ''} label="Copy" />
                          </li>
                          <li>
                            Team ID: <code>{oauthConfig.apple.teamId}</code>{' '}
                            <CopyButton text={oauthConfig.apple.teamId ?? ''} label="Copy" />
                          </li>
                          <li>
                            Key ID: <code>{oauthConfig.apple.keyId}</code>{' '}
                            <CopyButton text={oauthConfig.apple.keyId ?? ''} label="Copy" />
                          </li>
                          <li>
                            Private key (.p8 contents):{' '}
                            <CopyButton text={oauthConfig.apple.privateKey ?? ''} label="Copy key" />
                          </li>
                        </ol>
                      </>
                    )}
                  </div>
                )}
              </div>

              <div className="wizard-nav">
                <button type="button" className="btn-back" onClick={goBack}>
                  ← Back
                </button>
                <button type="button" className="btn btn-primary" onClick={goNext}>
                  Sign-in configured →
                </button>
              </div>
            </>
          )}

          {step === 5 && (
            <>
              <h2>Connect the app</h2>
              <p className="muted">
                From Supabase <strong>Project Settings → API</strong>, copy your{' '}
                <strong>anon public key</strong> below. Your project URL is already saved.
              </p>

              <label className="field">
                <span>Supabase Project URL</span>
                <input value={supabaseUrl} readOnly />
              </label>

              <label className="field">
                <span>Anon / publishable key</span>
                <input
                  value={anonKey}
                  onChange={(e) => setAnonKey(e.target.value)}
                  placeholder="eyJhbGciOiJIUzI1NiIs..."
                />
              </label>

              {connectJson && (
                <div className="connect-output">
                  <h3>Connect JSON</h3>
                  <div className="copy-row">
                    <CopyButton text={connectJson} label="Copy JSON" />
                  </div>
                  <textarea readOnly className="code-block" value={connectJson} rows={5} spellCheck={false} />

                  <h3>QR code for iOS app</h3>
                  <p className="muted">Staff scan this in SupaSupport → Connect → Scan QR Code.</p>
                  <div className="qr-wrap">
                    <QrImage value={connectJson} size={220} />
                  </div>

                  {iosDeepLink && (
                    <>
                      <h3>Open in iOS app</h3>
                      <p className="muted">
                        If the app is installed, this link opens connect directly (Safari on iPhone):
                      </p>
                      <a href={iosDeepLink} className="deep-link">
                        {iosDeepLink}
                      </a>
                    </>
                  )}

                  <div className="finish-actions">
                    <button type="button" className="btn btn-primary" onClick={connectOnWeb}>
                      Continue on web → Sign in
                    </button>
                  </div>
                </div>
              )}

              <div className="wizard-nav">
                <button type="button" className="btn-back" onClick={goBack}>
                  ← Back
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </PublicShell>
  )
}
