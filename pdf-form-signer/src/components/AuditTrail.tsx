import { useEffect, useRef } from 'react'
import { formatTime } from '../lib/format'
import type { AuditEvent } from '../types'

interface AuditTrailProps {
  events: AuditEvent[]
  onExport: () => void
}

export function AuditTrail({ events, onExport }: AuditTrailProps) {
  const listRef = useRef<HTMLOListElement>(null)

  useEffect(() => {
    const el = listRef.current
    if (el) el.scrollTop = el.scrollHeight
  }, [events.length])

  return (
    <aside className="audit" aria-labelledby="audit-title" data-panel="audit">
      <div className="audit__head">
        <h2 id="audit-title">Audit trail</h2>
        <span className="audit__live">Live</span>
        <span className="audit__count" aria-label={`${events.length} events`}>
          {events.length}
        </span>
      </div>
      <ol className="audit__list" ref={listRef} aria-live="polite">
        {events.length === 0 && <li className="audit__empty">Actions you take will be logged here.</li>}
        {events.map((e) => (
          <li key={e.id} className="audit__item" data-kind={e.kind}>
            <div className="audit__meta">
              <span className={`audit__badge audit__badge--${e.kind}`}>{e.kind}</span>
              <time className="audit__time" dateTime={e.time}>
                {formatTime(e.time)}
              </time>
            </div>
            <div className="audit__msg">{e.message}</div>
          </li>
        ))}
      </ol>
      <div className="audit__foot">
        <button type="button" className="btn btn--secondary btn--sm" onClick={onExport} disabled={events.length === 0}>
          Export as JSON
        </button>
      </div>
    </aside>
  )
}
