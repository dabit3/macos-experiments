import { useRef } from 'react'
import { kindMeta } from '../types'
import type { Diagram, Rect, Viewport } from '../types'
import { diagramBounds } from '../lib/geometry'
import './Minimap.css'

interface MinimapProps {
  diagram: Diagram
  viewport: Viewport
  canvasSize: { w: number; h: number }
  onViewportChange: (vp: Viewport) => void
}

const W = 220
const H = 150
const PAD = 12

export function Minimap({ diagram, viewport, canvasSize, onViewportChange }: MinimapProps) {
  const dragging = useRef(false)

  const view: Rect = {
    x: -viewport.x / viewport.zoom,
    y: -viewport.y / viewport.zoom,
    w: canvasSize.w / viewport.zoom,
    h: canvasSize.h / viewport.zoom,
  }
  const content = diagramBounds(diagram, 40)
  const world: Rect = content ? union(content, view) : view
  const scale = Math.min((W - PAD * 2) / world.w, (H - PAD * 2) / world.h)
  const ox = PAD + ((W - PAD * 2) - world.w * scale) / 2 - world.x * scale
  const oy = PAD + ((H - PAD * 2) - world.h * scale) / 2 - world.y * scale
  const toMini = (x: number, y: number) => ({ x: x * scale + ox, y: y * scale + oy })

  const centerOn = (clientX: number, clientY: number, el: SVGSVGElement) => {
    const rect = el.getBoundingClientRect()
    const mx = clientX - rect.left
    const my = clientY - rect.top
    const wx = (mx - ox) / scale
    const wy = (my - oy) / scale
    onViewportChange({
      zoom: viewport.zoom,
      x: canvasSize.w / 2 - wx * viewport.zoom,
      y: canvasSize.h / 2 - wy * viewport.zoom,
    })
  }

  const v = toMini(view.x, view.y)

  return (
    <div className="minimap" aria-label="Minimap">
      <svg
        width={W}
        height={H}
        onPointerDown={(e) => {
          if (e.button !== 0) return
          dragging.current = true
          e.currentTarget.setPointerCapture(e.pointerId)
          centerOn(e.clientX, e.clientY, e.currentTarget)
        }}
        onPointerMove={(e) => {
          if (dragging.current) centerOn(e.clientX, e.clientY, e.currentTarget)
        }}
        onPointerUp={(e) => {
          dragging.current = false
          e.currentTarget.releasePointerCapture(e.pointerId)
        }}
      >
        {diagram.nodes.map((n) => {
          const p = toMini(n.x, n.y)
          return (
            <rect
              key={n.id}
              x={p.x}
              y={p.y}
              width={Math.max(2, n.w * scale)}
              height={Math.max(2, n.h * scale)}
              rx={n.kind === 'start' || n.kind === 'end' ? 4 : 1.5}
              fill={kindMeta(n.kind).color}
              opacity={0.55}
            />
          )
        })}
        <rect className="minimap-view" x={v.x} y={v.y} width={view.w * scale} height={view.h * scale} rx={2} />
      </svg>
      <div className="minimap-caption">
        {diagram.nodes.length} nodes · {diagram.edges.length} edges
      </div>
    </div>
  )
}

function union(a: Rect, b: Rect): Rect {
  const x = Math.min(a.x, b.x)
  const y = Math.min(a.y, b.y)
  return { x, y, w: Math.max(a.x + a.w, b.x + b.w) - x, h: Math.max(a.y + a.h, b.y + b.h) - y }
}
