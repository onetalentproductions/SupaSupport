import type { Ticket } from '../types'

export interface DashboardAnalytics {
  adminCompletedCount: number
  mediaCompletedCount: number
  facilitiesCompletedCount: number
  monthlySubmissions: Array<{ id: string; label: string; count: number }>
  topSubmitters: Array<{ email: string; count: number }>
  levelSlices: Array<{ label: string; count: number }>
}

export function computeDashboardAnalytics(
  activeTickets: Ticket[],
  archivedTickets: Ticket[],
  adminEmail: string | null,
  mediaCompletedCount: number,
  facilitiesCompletedCount: number
): DashboardAnalytics {
  const normalizedAdmin = adminEmail?.toLowerCase().trim()
  const submissionTickets = [...activeTickets, ...archivedTickets]

  const adminCompletedCount = archivedTickets.filter(
    (ticket) => ticket.completed_by_email?.toLowerCase().trim() === normalizedAdmin
  ).length

  const monthlySubmissions: DashboardAnalytics['monthlySubmissions'] = []
  const now = new Date()
  for (let offset = 5; offset >= 0; offset -= 1) {
    const monthAnchor = new Date(now.getFullYear(), now.getMonth() - offset, 1)
    const monthEnd = new Date(monthAnchor.getFullYear(), monthAnchor.getMonth() + 1, 1)
    const count = submissionTickets.filter(
      (ticket) =>
        new Date(ticket.created_at) >= monthAnchor && new Date(ticket.created_at) < monthEnd
    ).length
    monthlySubmissions.push({
      id: `${monthAnchor.getFullYear()}-${monthAnchor.getMonth()}`,
      label: monthAnchor.toLocaleString(undefined, { month: 'short' }),
      count,
    })
  }

  const submitterMap = new Map<string, number>()
  for (const ticket of submissionTickets) {
    submitterMap.set(ticket.user_email, (submitterMap.get(ticket.user_email) ?? 0) + 1)
  }
  const topSubmitters = [...submitterMap.entries()]
    .map(([email, count]) => ({ email, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 5)

  const outOfScope = activeTickets.filter((ticket) => ticket.status === 'out_of_scope').length
  const active = activeTickets.filter((ticket) => ticket.status !== 'out_of_scope')
  const levelSlices = [
    { label: 'Low', count: active.filter((ticket) => ticket.priority === 'low').length },
    { label: 'Medium', count: active.filter((ticket) => ticket.priority === 'medium').length },
    {
      label: 'High',
      count: active.filter((ticket) => ticket.priority === 'high' || ticket.priority === 'urgent').length,
    },
    { label: 'Out of Scope', count: outOfScope },
  ].filter((slice) => slice.count > 0)

  return {
    adminCompletedCount,
    mediaCompletedCount,
    facilitiesCompletedCount,
    monthlySubmissions,
    topSubmitters,
    levelSlices,
  }
}
