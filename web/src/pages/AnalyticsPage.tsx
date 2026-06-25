import { useEffect, useMemo, useState } from 'react'
import { useAuth } from '../context/AuthContext'
import {
  fetchActiveTickets,
  fetchArchivedTickets,
  fetchDepartmentCompletionCounts,
} from '../lib/tickets'
import { computeDashboardAnalytics } from '../lib/analytics'
import { DepartmentCompletionBar } from '../components/DepartmentComponents'
import type { Ticket } from '../types'

export function AnalyticsPage() {
  const { session, email, isAdmin, adminDepartment } = useAuth()
  const [activeTickets, setActiveTickets] = useState<Ticket[]>([])
  const [archivedTickets, setArchivedTickets] = useState<Ticket[]>([])
  const [mediaCompletedCount, setMediaCompletedCount] = useState(0)
  const [facilitiesCompletedCount, setFacilitiesCompletedCount] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!session || !isAdmin || !adminDepartment) {
      setLoading(false)
      return
    }

    setLoading(true)
    Promise.all([
      fetchActiveTickets(session.user.id, true, adminDepartment),
      fetchArchivedTickets(adminDepartment),
      fetchDepartmentCompletionCounts(),
    ])
      .then(([active, archived, counts]) => {
        setActiveTickets(active)
        setArchivedTickets(archived)
        setMediaCompletedCount(counts.media)
        setFacilitiesCompletedCount(counts.facilities)
      })
      .catch((err) => setError(err instanceof Error ? err.message : 'Failed to load analytics'))
      .finally(() => setLoading(false))
  }, [session, isAdmin, adminDepartment])

  const analytics = useMemo(
    () =>
      computeDashboardAnalytics(
        activeTickets,
        archivedTickets,
        email,
        mediaCompletedCount,
        facilitiesCompletedCount
      ),
    [activeTickets, archivedTickets, email, mediaCompletedCount, facilitiesCompletedCount]
  )

  if (!isAdmin) {
    return (
      <div className="page">
        <p className="error-text">Analytics are only available to admins.</p>
      </div>
    )
  }

  const maxMonthly = Math.max(...analytics.monthlySubmissions.map((month) => month.count), 1)

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>Analytics</h1>
          <p className="muted">Department workload and completion stats.</p>
        </div>
      </div>

      {loading && <p className="muted">Loading analytics…</p>}
      {error && <p className="error-text">{error}</p>}

      {!loading && !error && (
        <div className="analytics-grid">
          <section className="card analytics-card">
            <h2>Tickets Closed by You</h2>
            <p className="analytics-score">{analytics.adminCompletedCount}</p>
            {email && <p className="muted card-inner">{email}</p>}
          </section>

          <section className="card analytics-card">
            <h2>Completed by Department</h2>
            <DepartmentCompletionBar
              mediaCount={analytics.mediaCompletedCount}
              facilitiesCount={analytics.facilitiesCompletedCount}
            />
          </section>

          <section className="card analytics-card">
            <h2>Monthly Submissions</h2>
            {analytics.monthlySubmissions.every((month) => month.count === 0) ? (
              <p className="muted card-inner">No tickets submitted yet.</p>
            ) : (
              <div className="monthly-chart">
                {analytics.monthlySubmissions.map((month) => (
                  <div key={month.id} className="monthly-bar-col">
                    <div
                      className="monthly-bar"
                      style={{ height: `${(month.count / maxMonthly) * 100}%` }}
                      title={`${month.count} tickets`}
                    />
                    <span>{month.label}</span>
                    <strong>{month.count}</strong>
                  </div>
                ))}
              </div>
            )}
          </section>

          <section className="card analytics-card">
            <h2>Top Submitters</h2>
            {analytics.topSubmitters.length === 0 ? (
              <p className="muted card-inner">No submitters yet.</p>
            ) : (
              <ul className="submitter-list">
                {analytics.topSubmitters.map((submitter, index) => (
                  <li key={submitter.email}>
                    <span>{index + 1}. {submitter.email}</span>
                    <strong>{submitter.count}</strong>
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section className="card analytics-card">
            <h2>Ticket Levels</h2>
            {analytics.levelSlices.length === 0 ? (
              <p className="muted card-inner">No active ticket data yet.</p>
            ) : (
              <ul className="submitter-list">
                {analytics.levelSlices.map((slice) => (
                  <li key={slice.label}>
                    <span>{slice.label}</span>
                    <strong>{slice.count}</strong>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      )}
    </div>
  )
}
