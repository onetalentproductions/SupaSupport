import { FormEvent, useEffect, useMemo, useState } from 'react'
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import {
  attachmentPublicUrl,
  detectAttachmentType,
  fetchAttachments,
  fetchMessages,
  fetchTicket,
  sendMessage,
  updateTicketDepartment,
  updateTicketStatus,
  uploadAttachment,
} from '../lib/tickets'
import type { Ticket, TicketAttachment, TicketDepartment, TicketMessage, TicketStatus } from '../types'
import { DepartmentBadge, PriorityBadge, StatusBadge, formatTimestamp } from '../components/Badges'
import { isOpenStatus } from '../types'

export function TicketDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const location = useLocation()
  const fromArchive = Boolean((location.state as { fromArchive?: boolean } | null)?.fromArchive)
  const { session, email, isAdmin } = useAuth()
  const [ticket, setTicket] = useState<Ticket | null>(null)
  const [messages, setMessages] = useState<TicketMessage[]>([])
  const [attachments, setAttachments] = useState<TicketAttachment[]>([])
  const [reply, setReply] = useState('')
  const [files, setFiles] = useState<File[]>([])
  const [loading, setLoading] = useState(true)
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const backPath = fromArchive || ticket?.status === 'complete' ? '/archive' : '/tickets'
  const backLabel = backPath === '/archive' ? 'Back to archive' : 'Back to tickets'

  const attachmentsByMessage = useMemo(() => {
    const map = new Map<string, TicketAttachment[]>()
    for (const attachment of attachments) {
      const list = map.get(attachment.message_id) ?? []
      list.push(attachment)
      map.set(attachment.message_id, list)
    }
    return map
  }, [attachments])

  const threadMessages = useMemo(() => {
    if (messages.length > 0) return messages
    if (!ticket?.description) return []
    return [
      {
        id: ticket.id,
        ticket_id: ticket.id,
        user_id: ticket.user_id,
        user_email: ticket.user_email,
        is_admin: false,
        body: ticket.description,
        created_at: ticket.created_at,
      } satisfies TicketMessage,
    ]
  }, [messages, ticket])

  async function load() {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      const [nextTicket, nextMessages, nextAttachments] = await Promise.all([
        fetchTicket(id),
        fetchMessages(id),
        fetchAttachments(id),
      ])
      setTicket(nextTicket)
      setMessages(nextMessages)
      setAttachments(nextAttachments)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load ticket')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [id])

  async function handleReply(e: FormEvent) {
    e.preventDefault()
    if (!session || !email || !ticket || !reply.trim()) return

    setSending(true)
    setError(null)
    const messageId = crypto.randomUUID()

    try {
      await sendMessage({
        id: messageId,
        ticketId: ticket.id,
        userId: session.user.id,
        userEmail: email,
        isAdmin,
        body: reply.trim(),
      })

      for (const file of files) {
        const fileType = detectAttachmentType(file)
        if (!fileType) continue
        await uploadAttachment({ ticketId: ticket.id, messageId, file, fileType })
      }

      setReply('')
      setFiles([])
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send reply')
    } finally {
      setSending(false)
    }
  }

  async function handleStatusChange(status: TicketStatus) {
    if (!ticket) return
    setSending(true)
    setError(null)
    try {
      await updateTicketStatus(ticket.id, status, email)
      if (status === 'complete') {
        navigate('/archive')
        return
      }
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update status')
    } finally {
      setSending(false)
    }
  }

  async function handleDepartmentChange(department: TicketDepartment) {
    if (!ticket) return
    setSending(true)
    setError(null)
    try {
      await updateTicketDepartment(ticket.id, department)
      navigate('/tickets')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to move ticket')
    } finally {
      setSending(false)
    }
  }

  if (loading) return <div className="page"><p className="muted">Loading ticket…</p></div>
  if (!ticket) return <div className="page"><p className="error-text">{error ?? 'Ticket not found'}</p></div>

  const canReply = isOpenStatus(ticket.status)

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <Link to={backPath} className="back-link">← {backLabel}</Link>
          <h1>{ticket.title}</h1>
          <div className="ticket-card-meta">
            <PriorityBadge priority={ticket.priority} />
            <StatusBadge status={ticket.status} />
            <DepartmentBadge department={ticket.department} />
            <span className="muted">{ticket.user_email}</span>
          </div>
        </div>
      </div>

      {isAdmin && (
        <div className="admin-bar card">
          <span>Admin actions</span>
          <div className="admin-actions">
            <button
              type="button"
              className="btn btn-small"
              disabled={sending || ticket.status === 'complete'}
              onClick={() => handleStatusChange('complete')}
            >
              Mark Complete
            </button>
            <button
              type="button"
              className="btn btn-small"
              disabled={sending || ticket.status === 'out_of_scope'}
              onClick={() => handleStatusChange('out_of_scope')}
            >
              Out of Scope
            </button>
            <button
              type="button"
              className="btn btn-small"
              disabled={sending || ticket.status === 'open'}
              onClick={() => handleStatusChange('open')}
            >
              Reopen
            </button>
            {ticket.department === 'media' ? (
              <button
                type="button"
                className="btn btn-small"
                disabled={sending}
                onClick={() => handleDepartmentChange('facilities')}
              >
                Move to Facilities
              </button>
            ) : (
              <button
                type="button"
                className="btn btn-small"
                disabled={sending}
                onClick={() => handleDepartmentChange('media')}
              >
                Move to Media
              </button>
            )}
          </div>
        </div>
      )}

      <div className="thread">
        {threadMessages.map((message, index) => (
          <article key={message.id} className="thread-post card">
            <div className="thread-post-header">
              <strong>{message.user_email}</strong>
              {message.is_admin && <span className="admin-pill">Admin</span>}
              {index === 0 && <span className="muted">Original post</span>}
              <span className="muted">{formatTimestamp(message.created_at)}</span>
            </div>
            <p>{message.body}</p>
            <div className="attachment-grid">
              {(attachmentsByMessage.get(message.id) ?? []).map((attachment) => (
                <AttachmentPreview key={attachment.id} attachment={attachment} />
              ))}
            </div>
          </article>
        ))}
      </div>

      {canReply ? (
        <form className="reply-bar card" onSubmit={handleReply}>
          <textarea
            value={reply}
            onChange={(e) => setReply(e.target.value)}
            placeholder="Write a reply…"
            rows={3}
          />
          <div className="reply-actions">
            <input
              type="file"
              accept="image/*,video/*"
              multiple
              onChange={(e) => setFiles(Array.from(e.target.files ?? []))}
            />
            <button type="submit" className="btn btn-primary" disabled={sending || !reply.trim()}>
              {sending ? 'Sending…' : 'Send Reply'}
            </button>
          </div>
        </form>
      ) : (
        <div className="closed-banner card">This ticket is closed. Replies are disabled.</div>
      )}

      {error && <p className="error-text">{error}</p>}
    </div>
  )
}

function AttachmentPreview({ attachment }: { attachment: TicketAttachment }) {
  const url = attachmentPublicUrl(attachment.file_path)
  if (attachment.file_type === 'video') {
    return <video controls className="attachment-media" src={url} />
  }
  return <img className="attachment-media" src={url} alt="Ticket attachment" />
}
