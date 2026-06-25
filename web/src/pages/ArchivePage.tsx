import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { fetchArchivedTickets } from '../lib/tickets'
import type { Ticket } from '../types'
import { DepartmentBadge, PriorityBadge, StatusBadge, formatTimestamp } from '../components/Badges'
import { DEPARTMENT_LABELS } from '../types'

export function ArchivePage() {
  const { isAdmin, adminDepartment } = useAuth()
  const [tickets, setTickets] = useState<Ticket[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!isAdmin || !adminDepartment) {
      setLoading(false)
      return
    }
    setLoading(true)
    fetchArchivedTickets(adminDepartment)
      .then(setTickets)
      .catch((err) => setError(err instanceof Error ? err.message : 'Failed to load archive'))
      .finally(() => setLoading(false))
  }, [isAdmin, adminDepartment])

  if (!isAdmin || !adminDepartment) {
    return (
      <div className="page">
        <p className="error-text">Archive is only available to department admins.</p>
      </div>
    )
  }

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>{DEPARTMENT_LABELS[adminDepartment]} Archive</h1>
          <p className="muted">Completed tickets for your department.</p>
        </div>
        <Link to="/tickets/new" className="btn btn-primary">
          New Ticket
        </Link>
      </div>

      {loading && <p className="muted">Loading archive…</p>}
      {error && <p className="error-text">{error}</p>}

      {!loading && !error && tickets.length === 0 && (
        <div className="empty-state-panel">
          <h2>No archived tickets</h2>
        </div>
      )}

      <div className="ticket-list">
        {tickets.map((ticket) => (
          <Link
            key={ticket.id}
            to={`/tickets/${ticket.id}`}
            state={{ fromArchive: true }}
            className="ticket-card card"
          >
            <div className="ticket-card-top">
              <h2>{ticket.title}</h2>
              <PriorityBadge priority={ticket.priority} />
            </div>
            {ticket.description && <p className="ticket-preview">{ticket.description}</p>}
            <div className="ticket-card-meta">
              <StatusBadge status={ticket.status} />
              <DepartmentBadge department={ticket.department} />
              <span className="muted">{ticket.user_email}</span>
              <span className="muted">
                {ticket.completed_at ? formatTimestamp(ticket.completed_at) : formatTimestamp(ticket.created_at)}
              </span>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}
