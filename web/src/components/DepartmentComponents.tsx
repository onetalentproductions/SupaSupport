import type { TicketDepartment } from '../types'
import { DEPARTMENT_LABELS } from '../types'

interface DepartmentToggleProps {
  value: TicketDepartment
  onChange: (department: TicketDepartment) => void
}

export function DepartmentToggle({ value, onChange }: DepartmentToggleProps) {
  return (
    <div className="dept-lever" role="group" aria-label="Ticket department">
      <div
        className={`dept-lever-slider ${value === 'media' ? 'is-media' : 'is-facilities'}`}
        aria-hidden="true"
      />
      <button
        type="button"
        className={`dept-lever-segment ${value === 'facilities' ? 'active' : ''}`}
        onClick={() => onChange('facilities')}
      >
        {DEPARTMENT_LABELS.facilities}
      </button>
      <button
        type="button"
        className={`dept-lever-segment ${value === 'media' ? 'active' : ''}`}
        onClick={() => onChange('media')}
      >
        {DEPARTMENT_LABELS.media}
      </button>
    </div>
  )
}

interface DepartmentCompletionBarProps {
  mediaCount: number
  facilitiesCount: number
}

export function DepartmentCompletionBar({ mediaCount, facilitiesCount }: DepartmentCompletionBarProps) {
  const total = Math.max(mediaCount + facilitiesCount, 1)
  const mediaPercent = (mediaCount / total) * 100

  if (mediaCount === 0 && facilitiesCount === 0) {
    return <p className="muted card-inner">No completed tickets yet.</p>
  }

  return (
    <div className="dept-completion">
      <div className="dept-completion-bar" aria-hidden="true">
        <div className="dept-completion-media" style={{ width: `${mediaPercent}%` }} />
        <div className="dept-completion-facilities" style={{ width: `${100 - mediaPercent}%` }} />
      </div>
      <div className="dept-completion-legend">
        <span>
          <span className="legend-dot media" /> Media <strong>{mediaCount}</strong>
        </span>
        <span>
          <strong>{facilitiesCount}</strong> Facilities <span className="legend-dot facilities" />
        </span>
      </div>
    </div>
  )
}
