import { Link } from 'react-router-dom'
import { config } from '../lib/config'
import { PublicShell } from '../components/Layout'

export function PrivacyPage() {
  const updated = 'June 21, 2026'

  return (
    <PublicShell>
      <article className="legal-page card">
        <p className="back-row">
          <Link to="/login">← Back</Link>
        </p>
        <h1>Privacy Policy</h1>
        <p className="muted">Last updated: {updated}</p>

        <p>
          This Privacy Policy describes how <strong>{config.siteName}</strong> (“we”, “us”) collects,
          uses, and protects information when you use our mobile app and website at{' '}
          <a href={config.siteUrl}>{config.siteUrl}</a>.
        </p>

        <h2>Who this applies to</h2>
        <p>
          FBCVR Tickets is an internal support tool for authorized FBCVR staff and designated test
          accounts. Access requires an approved Google account.
        </p>

        <h2>Information we collect</h2>
        <ul>
          <li>
            <strong>Account information:</strong> your Google account email address and user ID when
            you sign in.
          </li>
          <li>
            <strong>Ticket content:</strong> titles, descriptions, replies, and status updates you
            submit.
          </li>
          <li>
            <strong>Attachments:</strong> photos or videos you choose to upload with a ticket.
          </li>
          <li>
            <strong>Push notification token (mobile only):</strong> if you allow notifications, we
            store a device token to send alerts about ticket updates.
          </li>
          <li>
            <strong>Technical data:</strong> standard server logs from our hosting providers (e.g.
            timestamps, IP address) for security and reliability.
          </li>
        </ul>

        <h2>How we use information</h2>
        <ul>
          <li>Authenticate you and restrict access to authorized users</li>
          <li>Create, display, and manage support tickets</li>
          <li>Notify admins and users about new tickets or replies</li>
          <li>Maintain security and troubleshoot service issues</li>
        </ul>

        <h2>Where data is stored</h2>
        <p>
          Data is stored in <strong>Supabase</strong> (cloud database and file storage). Sign-in is
          handled by <strong>Google</strong>. We do not sell your personal information.
        </p>

        <h2>Who can see your data</h2>
        <ul>
          <li>You can view your own tickets and replies.</li>
          <li>Authorized FBCVR administrators can view tickets to provide support.</li>
          <li>Our infrastructure providers process data on our behalf to operate the service.</li>
        </ul>

        <h2>Retention</h2>
        <p>
          Ticket data is retained while the service is in use for support and operational purposes.
          Contact us if you need a ticket removed.
        </p>

        <h2>Security</h2>
        <p>
          We use industry-standard HTTPS encryption in transit and access controls via Supabase Row
          Level Security. No method of transmission or storage is 100% secure.
        </p>

        <h2>Your choices</h2>
        <ul>
          <li>You can sign out at any time.</li>
          <li>You can decline push notifications on mobile.</li>
          <li>Attachments are optional.</li>
        </ul>

        <h2>Children</h2>
        <p>This service is not intended for children and is limited to authorized staff use.</p>

        <h2>Changes</h2>
        <p>We may update this policy from time to time. The “Last updated” date will reflect changes.</p>

        <h2>Contact</h2>
        <p>
          Questions about this policy:{' '}
          <a href={`mailto:${config.supportEmail}`}>{config.supportEmail}</a>
        </p>
      </article>
    </PublicShell>
  )
}
