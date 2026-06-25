import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { fetchActiveTickets } from '../lib/tickets'
import type { Ticket } from '../types'
import { DepartmentBadge, PriorityBadge, StatusBadge, formatTimestamp } from '../components/Badges'
import { DEPARTMENT_LABELS } from '../types'

export function TicketsPage() {
  const { session, isAdmin, adminDepartment } = useAuth()
  const [tickets, setTickets] = useState<Ticket[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showCompletedTickets, setShowCompletedTickets] = useState(false)

  useEffect(() => {
    if (!session) return
    setLoading(true)
    fetchActiveTickets(session.user.id, isAdmin, adminDepartment)
      .then(setTickets)
      .catch((err) => setError(err instanceof Error ? err.message : 'Failed to load tickets'))
      .finally(() => setLoading(false))
  }, [session, isAdmin, adminDepartment])

  const displayedTickets = useMemo(() => {
    if (isAdmin || showCompletedTickets) return tickets
    return tickets.filter((ticket) => ticket.status !== 'complete')
  }, [isAdmin, showCompletedTickets, tickets])

  const heading = isAdmin
    ? adminDepartment
      ? `${DEPARTMENT_LABELS[adminDepartment]} Tickets`
      : 'Tickets'
    : 'My Tickets'

  return (
    <div className="page tickets-page">
      <div className="page-header">
        <div>
          <h1>{heading}</h1>
          <p className="muted">
            {isAdmin ? 'Open tickets for your department.' : 'Track your support requests.'}
          </p>
        </div>
        <Link to="/tickets/new" className="btn btn-primary">
          New Ticket
        </Link>
      </div>

      {loading && <p className="muted">Loading tickets…</p>}
      {error && <p className="error-text">{error}</p>}

      {!loading && !error && displayedTickets.length === 0 && (
        <div className="empty-state-panel">
          <h2>No open tickets</h2>
        </div>
      )}

      <div className="ticket-list">
        {displayedTickets.map((ticket) => (
          <Link key={ticket.id} to={`/tickets/${ticket.id}`} className="ticket-card card">
            <div className="ticket-card-top">
              <h2>{ticket.title}</h2>
              <PriorityBadge priority={ticket.priority} />
            </div>
            {ticket.description && <p className="ticket-preview">{ticket.description}</p>}
            <div className="ticket-card-meta">
              <StatusBadge status={ticket.status} />
              <DepartmentBadge department={ticket.department} />
              {isAdmin && <span className="muted">{ticket.user_email}</span>}
              <span className="muted">{formatTimestamp(ticket.created_at)}</span>
            </div>
          </Link>
        ))}
      </div>

      {!isAdmin && (
        <button
          type="button"
          className="completed-toggle-fab"
          aria-label={showCompletedTickets ? 'Hide completed tickets' : 'Show completed tickets'}
          onClick={() => setShowCompletedTickets((value) => !value)}
        >
          {showCompletedTickets ? (
            <EyeIcon />
          ) : (
            <EyeSlashIcon />
          )}
        </button>
      )}
    </div>
  )
}

function EyeIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M2 12C4.5 7 8.5 4 12 4s7.5 3 10 8c-2.5 5-6.5 8-10 8s-7.5-3-10-8Z"
        stroke="currentColor"
        strokeWidth="2"
      />
      <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="2" />
    </svg>
  )
}

function EyeSlashIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M3 3l18 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      <path
        d="M10.6 10.6A3 3 0 0 0 12 15a3 3 0 0 0 2.4-1.2M6.7 6.7C4.8 8 3.2 10 2 12c2.5 5 6.5 8 10 8 1.8 0 3.5-.5 5-1.5M9.9 5.1A10.8 10.8 0 0 1 12 4c3.5 0 7.5 3 10 8-1 2-2.4 3.7-4 5"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  )
}
