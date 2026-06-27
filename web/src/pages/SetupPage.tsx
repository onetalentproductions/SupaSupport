import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { appConfig } from '../lib/config'
import { encodeConnectPayload, saveTenant } from '../lib/tenant'
import { resetSupabaseClient } from '../lib/supabase'
import { buildFullBootstrapSql, type SetupWizardInput } from '../lib/setupSql'
import { PublicShell } from '../components/Layout'
import { CopyButton } from '../components/CopyButton'
import { QrImage } from '../components/QrImage'

const STEPS = [
  'Organization',
  'Create Supabase',
  'Run SQL',
  'Storage',
  'Auth',
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
                  Open <strong>Project Settings → API</strong> and keep that tab open — you will need the
                  Project URL and anon public key in step 6.
                </li>
              </ol>
              <div className="wizard-nav">
                <button type="button" className="btn btn-ghost" onClick={goBack}>
                  ← Back
                </button>
                <button type="button" className="btn btn-primary" onClick={goNext}>
                  I have a project →
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
                <button type="button" className="btn btn-ghost" onClick={goBack}>
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
                <button type="button" className="btn btn-ghost" onClick={goBack}>
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
              <h2>Enable sign-in providers</h2>
              <p className="muted">
                In Supabase, open <strong>Authentication → Providers</strong> and enable at least one
                provider your team will use.
              </p>
              <ul className="instruction-list">
                <li>
                  <strong>Google</strong> — enable, add OAuth client ID/secret from Google Cloud Console.
                  Add redirect URL:{' '}
                  <code>{supabaseUrl ? `${supabaseUrl.replace(/\/$/, '')}/auth/v1/callback` : 'https://YOUR_PROJECT.supabase.co/auth/v1/callback'}</code>
                </li>
                <li>
                  <strong>Apple</strong> — enable for the iOS app (configure Services ID + key in Apple
                  Developer).
                </li>
              </ul>
              <p className="fine-print">
                Web sign-in uses Google OAuth with redirect back to this site after you connect.
              </p>
              <div className="wizard-nav">
                <button type="button" className="btn btn-ghost" onClick={goBack}>
                  ← Back
                </button>
                <button type="button" className="btn btn-primary" onClick={goNext}>
                  Auth configured →
                </button>
              </div>
            </>
          )}

          {step === 5 && (
            <>
              <h2>Connect the app</h2>
              <p className="muted">
                From Supabase <strong>Project Settings → API</strong>, paste your project URL and anon
                public key below.
              </p>

              <label className="field">
                <span>Supabase Project URL</span>
                <input
                  value={supabaseUrl}
                  onChange={(e) => setSupabaseUrl(e.target.value)}
                  placeholder="https://xxxxx.supabase.co"
                />
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
                <button type="button" className="btn btn-ghost" onClick={goBack}>
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
