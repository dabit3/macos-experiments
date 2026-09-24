import { NODE_KINDS } from '../types'
import type { NodeKind } from '../types'
import { Icon, ShapeIcon } from './Icons'
import './Palette.css'

interface PaletteProps {
  onDragStart: (kind: NodeKind, e: React.PointerEvent) => void
  onShowShortcuts: () => void
}

export function Palette({ onDragStart, onShowShortcuts }: PaletteProps) {
  return (
    <aside className="palette" aria-label="Node palette">
      <div className="palette-head">
        <h2 className="palette-title">Shapes</h2>
        <p className="palette-hint">Drag onto the canvas</p>
      </div>
      <div className="palette-list">
        {NODE_KINDS.map((meta) => (
          <button
            key={meta.kind}
            type="button"
            className="palette-item"
            data-kind={meta.kind}
            title={`Drag to add a ${meta.name} node (${meta.hint})`}
            onPointerDown={(e) => {
              if (e.button !== 0) return
              onDragStart(meta.kind, e)
            }}
            style={{ '--kind-color': meta.color } as React.CSSProperties}
          >
            <ShapeIcon kind={meta.kind} color={meta.color} />
            <span className="palette-name">{meta.name}</span>
          </button>
        ))}
      </div>
      <div className="palette-footer">
        <button type="button" className="palette-link" onClick={onShowShortcuts} data-action="shortcuts">
          <Icon name="keyboard" size={16} />
          <span>Keyboard shortcuts</span>
          <kbd>?</kbd>
        </button>
      </div>
    </aside>
  )
}
