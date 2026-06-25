import type { TicketPriority, TicketStatus, TicketDepartment } from '../types'
import { PRIORITY_LABELS, STATUS_LABELS, DEPARTMENT_LABELS } from '../types'
import './Badges.css'

export function PriorityBadge({ priority }: { priority: TicketPriority }) {
  return <span className={`badge priority-${priority}`}>{PRIORITY_LABELS[priority]}</span>
}

export function StatusBadge({ status }: { status: TicketStatus }) {
  return <span className={`badge status-${status}`}>{STATUS_LABELS[status]}</span>
}

export function DepartmentBadge({ department }: { department: TicketDepartment }) {
  return <span className={`badge department-${department}`}>{DEPARTMENT_LABELS[department]}</span>
}

export function formatTimestamp(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value))
}
