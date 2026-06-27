import { Link } from 'react-router-dom'
import { appConfig } from '../lib/config'
import { PublicShell } from '../components/Layout'
import '../landing.css'

export function LandingPage() {
  return (
    <PublicShell>
      <div className="landing">
        <header className="landing-hero">
          <div className="landing-logo">SS</div>
          <h1>{appConfig.appName}</h1>
          <p className="landing-lead">
            A mobile-first helpdesk for your team. Each organization runs its own private Supabase
            project — your tickets never live on our servers.
          </p>
          <div className="landing-actions">
            <Link to="/setup" className="btn btn-primary landing-cta">
              Create server
            </Link>
            <Link to="/connect" className="btn btn-ghost landing-cta-secondary">
              Connect to existing
            </Link>
          </div>
        </header>

        <section className="landing-section">
          <h2>How it works</h2>
          <ol className="landing-steps">
            <li>
              <strong>Create a free Supabase project</strong> — our wizard generates the SQL you paste
              in one step.
            </li>
            <li>
              <strong>Connect the iOS app</strong> — scan a QR code or paste a short JSON payload.
            </li>
            <li>
              <strong>Sign in with Google or Apple</strong> — admins pre-approve emails or allow your
              domain.
            </li>
            <li>
              <strong>Submit and track tickets</strong> — departments, priorities, attachments, and
              admin analytics included.
            </li>
          </ol>
        </section>

        <section className="landing-section landing-grid">
          <article className="landing-card">
            <h3>Your data, your database</h3>
            <p>
              No shared multi-tenant backend. Each church, school, or team owns their Supabase project
              and controls who can sign in.
            </p>
          </article>
          <article className="landing-card">
            <h3>Built for phones</h3>
            <p>
              Staff open tickets from the field. Admins reply, reassign, and close from the same app —
              or use the web client.
            </p>
          </article>
          <article className="landing-card">
            <h3>Simple onboarding</h3>
            <p>
              One SQL script sets up tables, security rules, and your first admin. Share a QR code so
              users join in seconds.
            </p>
          </article>
        </section>

        <section className="landing-section landing-footer-cta">
          <h2>Ready to set up?</h2>
          <p className="muted">Takes about 15 minutes if you already have a Supabase account.</p>
          <Link to="/setup" className="btn btn-primary">
            Start setup wizard →
          </Link>
        </section>
      </div>
    </PublicShell>
  )
}
