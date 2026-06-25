import { getSupabase } from './supabase'
import { loadTenant } from './tenant'
import type {
  AttachmentType,
  Ticket,
  TicketAttachment,
  TicketDepartment,
  TicketMessage,
  TicketPriority,
  TicketStatus,
} from '../types'

function db() {
  return getSupabase()
}

function mediaBucket() {
  return loadTenant()?.mediaBucket ?? 'ticket-media'
}

export async function fetchActiveTickets(
  userId: string,
  isAdmin: boolean,
  adminDepartment: TicketDepartment | null
): Promise<Ticket[]> {
  let query = db().from('tickets').select('*')
  if (isAdmin && adminDepartment) {
    query = query
      .eq('department', adminDepartment)
      .neq('status', 'complete')
  } else if (!isAdmin) {
    query = query.eq('user_id', userId)
  }
  const { data, error } = await query.order('created_at', { ascending: false })
  if (error) throw error
  return data as Ticket[]
}

export async function fetchArchivedTickets(department: TicketDepartment): Promise<Ticket[]> {
  const { data, error } = await db()
    .from('tickets')
    .select('*')
    .eq('department', department)
    .eq('status', 'complete')
    .order('completed_at', { ascending: false })
  if (error) throw error
  return data as Ticket[]
}

export async function fetchDepartmentCompletionCounts(): Promise<{ media: number; facilities: number }> {
  const { data, error } = await db().rpc('get_department_completion_counts')
  if (error) throw error
  const row = (data as Array<{ media_count: number; facilities_count: number }> | null)?.[0]
  return {
    media: row?.media_count ?? 0,
    facilities: row?.facilities_count ?? 0,
  }
}

export async function fetchTicket(id: string): Promise<Ticket> {
  const { data, error } = await db().from('tickets').select('*').eq('id', id).single()
  if (error) throw error
  return data as Ticket
}

export async function createTicket(input: {
  userId: string
  userEmail: string
  title: string
  description: string
  priority: TicketPriority
  department: TicketDepartment
}): Promise<Ticket> {
  const { data, error } = await db()
    .from('tickets')
    .insert({
      user_id: input.userId,
      user_email: input.userEmail,
      title: input.title,
      description: input.description,
      priority: input.priority,
      department: input.department,
    })
    .select()
    .single()
  if (error) throw error
  return data as Ticket
}

export async function updateTicketStatus(
  id: string,
  status: TicketStatus,
  closedByEmail?: string | null
) {
  const { error } = await db()
    .from('tickets')
    .update({
      status,
      completed_at: status === 'open' ? null : new Date().toISOString(),
      completed_by_email: status === 'complete' ? closedByEmail ?? null : null,
    })
    .eq('id', id)
  if (error) throw error
}

export async function updateTicketDepartment(id: string, department: TicketDepartment) {
  const { error } = await db().from('tickets').update({ department }).eq('id', id)
  if (error) throw error
}

export async function fetchMessages(ticketId: string): Promise<TicketMessage[]> {
  const { data, error } = await db()
    .from('ticket_messages')
    .select('*')
    .eq('ticket_id', ticketId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return data as TicketMessage[]
}

export async function sendMessage(input: {
  id: string
  ticketId: string
  userId: string
  userEmail: string
  isAdmin: boolean
  body: string
}) {
  const { error } = await db().from('ticket_messages').insert({
    id: input.id,
    ticket_id: input.ticketId,
    user_id: input.userId,
    user_email: input.userEmail,
    is_admin: input.isAdmin,
    body: input.body,
  })
  if (error) throw error
}

export async function fetchAttachments(ticketId: string): Promise<TicketAttachment[]> {
  const { data, error } = await db()
    .from('ticket_attachments')
    .select('*')
    .eq('ticket_id', ticketId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return data as TicketAttachment[]
}

export async function uploadAttachment(input: {
  ticketId: string
  messageId: string
  file: File
  fileType: AttachmentType
}): Promise<TicketAttachment> {
  const ext = input.file.name.split('.').pop() ?? 'bin'
  const path = `${input.ticketId}/${input.messageId}/${crypto.randomUUID()}.${ext}`

  const { error: uploadError } = await db().storage
    .from(mediaBucket())
    .upload(path, input.file, { contentType: input.file.type, upsert: false })
  if (uploadError) throw uploadError

  const { data, error } = await db()
    .from('ticket_attachments')
    .insert({
      message_id: input.messageId,
      ticket_id: input.ticketId,
      file_path: path,
      file_type: input.fileType,
    })
    .select()
    .single()
  if (error) throw error
  return data as TicketAttachment
}

export function attachmentPublicUrl(path: string): string {
  const { data } = db().storage.from(mediaBucket()).getPublicUrl(path)
  return data.publicUrl
}

export function detectAttachmentType(file: File): AttachmentType | null {
  if (file.type.startsWith('image/')) return 'image'
  if (file.type.startsWith('video/')) return 'video'
  return null
}
