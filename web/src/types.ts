export type TicketPriority = 'low' | 'medium' | 'high' | 'urgent'
export type TicketStatus = 'open' | 'complete' | 'out_of_scope'
export type TicketDepartment = 'media' | 'facilities'
export type AttachmentType = 'image' | 'video'

export interface Ticket {
  id: string
  user_id: string
  user_email: string
  title: string
  description: string
  priority: TicketPriority
  status: TicketStatus
  department: TicketDepartment
  created_at: string
  updated_at: string
  completed_at: string | null
  completed_by_email: string | null
}

export interface TicketMessage {
  id: string
  ticket_id: string
  user_id: string
  user_email: string
  is_admin: boolean
  body: string | null
  created_at: string
}

export interface TicketAttachment {
  id: string
  message_id: string
  ticket_id: string
  file_path: string
  file_type: AttachmentType
  created_at: string
}

export const PRIORITY_LABELS: Record<TicketPriority, string> = {
  low: 'Low',
  medium: 'Medium',
  high: 'High',
  urgent: 'Urgent',
}

export const STATUS_LABELS: Record<TicketStatus, string> = {
  open: 'Open',
  complete: 'Complete',
  out_of_scope: 'Out of Scope',
}

export const DEPARTMENT_LABELS: Record<TicketDepartment, string> = {
  media: 'Media',
  facilities: 'Facilities',
}

export function isOpenStatus(status: TicketStatus) {
  return status === 'open'
}
