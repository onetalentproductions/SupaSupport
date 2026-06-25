import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { appConfig } from '../lib/config'
import { encodeConnectPayload } from '../lib/tenant'
import { PublicShell } from '../components/Layout'

export function SetupPage() {
  const [orgName, setOrgName] = useState('My Organization')
  const [supabaseUrl, setSupabaseUrl] = useState('')
  const [anonKey, setAnonKey] = useState('')
  const [adminEmail, setAdminEmail] = useState('')
  const [departments, setDepartments] = useState('Facilities\nMedia')
  const [accessMode, setAccessMode] = useState<'invite_only' | 'domain'>('invite_only')
  const [allowedDomain, setAllowedDomain] = useState('@example.com')

  const departmentLines = useMemo(
    () =>
      departments
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean),
    [departments]
  )

  const bootstrapSql = useMemo(() => {
    const slug = (label: string, index: number) =>
      label
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '_')
        .replace(/^_|_$/g, '') || `dept_${index}`

    const deptRows = departmentLines
      .map((label, index) => {
        const s = slug(label, index)
        return `    ('${s}', '${label.replace(/'/g, "''")}', ${index})`
      })
      .join(',\n')

    const adminSlugList = departmentLines.map((label, index) => `'${slug(label, index)}'`).join(', ')

    return `-- SupaSupport bootstrap for ${orgName}
-- 1. Run this in Supabase SQL Editor
-- 2. Create Storage bucket: ticket-media
-- 3. Enable Google + Apple auth providers

-- Paste full contents of supabase/bootstrap.sql from the repo, then run:

UPDATE org_settings SET
  org_name = '${orgName.replace(/'/g, "''")}',
  access_mode = '${accessMode}'${accessMode === 'domain' ? `,\n  allowed_domain = '${allowedDomain.replace(/'/g, "''")}'` : ''}
WHERE id = 1;

DELETE FROM departments;
INSERT INTO departments (slug, label, sort_order) VALUES
${deptRows || "    ('general', 'General', 0)"};

INSERT INTO pending_members (email, role, department_slugs)
VALUES ('${adminEmail.replace(/'/g, "''")}', 'admin', ARRAY[${adminSlugList || "'general'"}]);
`
  }, [orgName, adminEmail, departmentLines, accessMode, allowedDomain])

  const orgConnectJson =
    supabaseUrl && anonKey
      ? encodeConnectPayload({
          orgName,
          supabaseUrl: supabaseUrl.trim(),
          supabaseAnonKey: anonKey.trim(),
          mediaBucket: 'ticket-media',
        })
      : ''

  return (
    <PublicShell>
      <div className="login-card" style={{ maxWidth: 720, textAlign: 'left' }}>
        <h1>Set up {appConfig.appName}</h1>
        <p className="muted">Create a Supabase project, customize below, run the SQL, then share the connect JSON as a QR.</p>

        <label>Organization name</label>
        <input value={orgName} onChange={(e) => setOrgName(e.target.value)} style={{ width: '100%' }} />

        <label>First admin email</label>
        <input value={adminEmail} onChange={(e) => setAdminEmail(e.target.value)} style={{ width: '100%' }} />

        <label>Departments (one per line)</label>
        <textarea value={departments} onChange={(e) => setDepartments(e.target.value)} rows={4} style={{ width: '100%' }} />

        <label>Access mode</label>
        <select value={accessMode} onChange={(e) => setAccessMode(e.target.value as 'invite_only' | 'domain')}>
          <option value="invite_only">Invite / pre-added email only (recommended)</option>
          <option value="domain">Email domain allowlist (optional)</option>
        </select>
        {accessMode === 'domain' && (
          <>
            <label>Allowed domain</label>
            <input value={allowedDomain} onChange={(e) => setAllowedDomain(e.target.value)} style={{ width: '100%' }} />
          </>
        )}

        <h3>Generated SQL snippet</h3>
        <textarea readOnly value={bootstrapSql} rows={14} style={{ width: '100%', fontFamily: 'monospace', fontSize: 12 }} />

        <h3>Org connect JSON (QR encode this for staff)</h3>
        <input placeholder="Supabase URL" value={supabaseUrl} onChange={(e) => setSupabaseUrl(e.target.value)} style={{ width: '100%' }} />
        <input placeholder="Anon / publishable key" value={anonKey} onChange={(e) => setAnonKey(e.target.value)} style={{ width: '100%' }} />
        {orgConnectJson && (
          <textarea readOnly value={orgConnectJson} rows={6} style={{ width: '100%', fontFamily: 'monospace', fontSize: 12 }} />
        )}

        <p className="fine-print">
          Full schema: run <code>supabase/bootstrap.sql</code> from the repo. Then paste your Supabase URL + key above to generate staff QR JSON.
        </p>
        <p className="fine-print">
          <Link to="/connect">← Back to connect</Link>
        </p>
      </div>
    </PublicShell>
  )
}
