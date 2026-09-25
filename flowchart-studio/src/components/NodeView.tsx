import { memo } from 'react'
import { PORT_SIDES, kindMeta } from '../types'
import type { FlowNode, PortSide } from '../types'
import { portPosition, shapePath, wrapLabel } from '../lib/geometry'

interface NodeViewProps {
  node: FlowNode
  selected: boolean
  editing: boolean
  targetPort: PortSide | null
  connecting: boolean
}

const LINE_HEIGHT = 17

export const NodeView = memo(function NodeView({ node, selected, editing, targetPort, connecting }: NodeViewProps) {
  const meta = kindMeta(node.kind)
  const lines = wrapLabel(node.label, node.kind === 'decision' ? 14 : 18)
  const cx = node.x + node.w / 2
  const cy = node.y + node.h / 2
  const startY = cy - ((lines.length - 1) * LINE_HEIGHT) / 2
  const className = `node node-${node.kind}${selected ? ' is-selected' : ''}${connecting ? ' is-connecting' : ''}${
    targetPort ? ' is-target' : ''
  }`

  return (
    <g className={className} data-node-id={node.id} style={{ '--node-color': meta.color } as React.CSSProperties}>
      {selected && <path className="node-halo" d={shapePath(node)} />}
      <path className="node-shape" d={shapePath(node)} />
      {!editing && (
        <text className="node-label" x={cx} y={startY} textAnchor="middle" dominantBaseline="central">
          {lines.map((line, i) => (
            <tspan key={i} x={cx} dy={i === 0 ? 0 : LINE_HEIGHT}>
              {line}
            </tspan>
          ))}
        </text>
      )}
      {PORT_SIDES.map((side) => {
        const p = portPosition(node, side)
        const isTarget = targetPort === side
        return (
          <g key={side} className={`port port-${side}${isTarget ? ' is-target' : ''}`} data-port={side}>
            <circle className="port-hit" cx={p.x} cy={p.y} r={13} />
            <circle className="port-dot" cx={p.x} cy={p.y} r={isTarget ? 8 : 5.5} />
          </g>
        )
      })}
    </g>
  )
})
