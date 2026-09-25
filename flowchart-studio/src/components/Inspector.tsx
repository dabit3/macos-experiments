import { useState } from 'react'
import { NODE_KINDS, kindMeta } from '../types'
import type { FlowEdge, FlowNode, NodeKind, Selection } from '../types'
import { Icon } from './Icons'
import './Inspector.css'

interface InspectorProps {
  selection: Selection
  node: FlowNode | null
  edge: FlowEdge | null
  onLabelChange: (value: string) => void
  onKindChange: (kind: NodeKind) => void
  onDelete: () => void
  sourceLabel?: string
  targetLabel?: string
}

export function Inspector({ selection, node, edge, onLabelChange, onKindChange, onDelete, sourceLabel, targetLabel }: InspectorProps) {
  const total = selection.nodes.length + selection.edges.length
  const current = node?.label ?? edge?.label ?? ''
  const [draft, setDraft] = useState(current)
  const [seen, setSeen] = useState(current)
  if (seen !== current) {
    setSeen(current)
    setDraft(current)
  }

  if (total === 0) return null

  const commit = () => {
    if (draft !== current) onLabelChange(draft)
  }

  if (total > 1 || (!node && !edge)) {
    return (
      <aside className="inspector">
        <div className="inspector-head">
          <span className="inspector-title">
            {selection.nodes.length} node{selection.nodes.length === 1 ? '' : 's'}
            {selection.edges.length > 0 && `, ${selection.edges.length} edge${selection.edges.length === 1 ? '' : 's'}`}
          </span>
        </div>
        <p className="inspector-hint">Drag any selected node to move the group. Ctrl+D duplicates.</p>
        <button type="button" className="inspector-danger" onClick={onDelete}>
          <Icon name="trash" size={16} /> Delete selection
        </button>
      </aside>
    )
  }

  const color = node ? kindMeta(node.kind).color : 'var(--edge)'

  return (
    <aside className="inspector" style={{ '--node-color': color } as React.CSSProperties}>
      <div className="inspector-head">
        <span className="inspector-swatch" />
        <span className="inspector-title">{node ? `${kindMeta(node.kind).name} node` : 'Edge'}</span>
      </div>
      <label className="inspector-field">
        <span>Label</span>
        <input
          value={draft}
          placeholder={edge ? 'e.g. Yes / No' : 'Label'}
          onChange={(e) => setDraft(e.target.value)}
          onBlur={commit}
          onKeyDown={(e) => {
            e.stopPropagation()
            if (e.key === 'Enter') {
              commit()
              e.currentTarget.blur()
            }
          }}
        />
      </label>
      {node && (
        <label className="inspector-field">
          <span>Shape</span>
          <select value={node.kind} onChange={(e) => onKindChange(e.target.value as NodeKind)}>
            {NODE_KINDS.map((k) => (
              <option key={k.kind} value={k.kind}>
                {k.name}
              </option>
            ))}
          </select>
        </label>
      )}
      {edge && (
        <p className="inspector-hint">
          From <b>{sourceLabel}</b> to <b>{targetLabel}</b>
        </p>
      )}
      <button type="button" className="inspector-danger" onClick={onDelete}>
        <Icon name="trash" size={16} /> Delete
      </button>
    </aside>
  )
}
