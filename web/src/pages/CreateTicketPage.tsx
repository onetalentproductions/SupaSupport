import { FormEvent, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import {
  createTicket,
  detectAttachmentType,
  sendMessage,
  uploadAttachment,
} from '../lib/tickets'
import type { TicketDepartment, TicketPriority } from '../types'
import { DepartmentToggle } from '../components/DepartmentComponents'

export function CreateTicketPage() {
  const { session, email, isAdmin } = useAuth()
  const navigate = useNavigate()
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [priority, setPriority] = useState<TicketPriority>('medium')
  const [department, setDepartment] = useState<TicketDepartment>('facilities')
  const [files, setFiles] = useState<File[]>([])
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!session || !email) return

    setSubmitting(true)
    setError(null)

    try {
      const ticket = await createTicket({
        userId: session.user.id,
        userEmail: email,
        title: title.trim(),
        description: description.trim(),
        priority,
        department,
      })

      const messageBody = description.trim() || 'Ticket created.'
      const messageId = crypto.randomUUID()
      await sendMessage({
        id: messageId,
        ticketId: ticket.id,
        userId: session.user.id,
        userEmail: email,
        isAdmin,
        body: messageBody,
      })

      for (const file of files) {
        const fileType = detectAttachmentType(file)
        if (!fileType) continue
        await uploadAttachment({
          ticketId: ticket.id,
          messageId,
          file,
          fileType,
        })
      }

      navigate(`/tickets/${ticket.id}`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create ticket')
      setSubmitting(false)
    }
  }

  return (
    <div className="page narrow">
      <div className="page-header">
        <div>
          <h1>New Ticket</h1>
          <p className="muted">
            {isAdmin
              ? 'Log an issue for tracking — pick the correct department.'
              : 'Describe the issue and optionally attach photos or videos.'}
          </p>
        </div>
        <Link to="/tickets" className="btn btn-ghost">
          Cancel
        </Link>
      </div>

      <form className="card form-card" onSubmit={onSubmit}>
        <label>
          Title
          <input value={title} onChange={(e) => setTitle(e.target.value)} required maxLength={200} />
        </label>

        <label>
          Department
          <DepartmentToggle value={department} onChange={setDepartment} />
        </label>

        <label>
          Priority
          <select value={priority} onChange={(e) => setPriority(e.target.value as TicketPriority)}>
            <option value="low">Low</option>
            <option value="medium">Medium</option>
            <option value="high">High</option>
            <option value="urgent">Urgent</option>
          </select>
        </label>

        <label>
          Description
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={6}
            placeholder="Describe the issue…"
          />
        </label>

        <label>
          Attachments (optional)
          <input
            type="file"
            accept="image/*,video/*"
            multiple
            onChange={(e) => setFiles(Array.from(e.target.files ?? []))}
          />
        </label>

        {files.length > 0 && (
          <ul className="file-list">
            {files.map((file) => (
              <li key={`${file.name}-${file.size}`}>{file.name}</li>
            ))}
          </ul>
        )}

        {error && <p className="error-text">{error}</p>}

        <button type="submit" className="btn btn-primary" disabled={submitting || !title.trim()}>
          {submitting ? 'Submitting…' : 'Submit Ticket'}
        </button>
      </form>
    </div>
  )
}
