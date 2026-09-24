import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { GRID, MAX_ZOOM, MIN_ZOOM } from '../types'
import type { Diagram, EdgeStyle, FlowEdge, FlowNode, Point, PortSide, Rect, Selection, Viewport } from '../types'
import type { History } from '../hooks/useHistory'
import {
  arrowHead,
  edgeEndpoints,
  nearestPort,
  normalizeRect,
  pointInNode,
  polylineMidpoint,
  polylinePath,
  portPosition,
  rectsIntersect,
  routeEdge,
  routePoints,
  screenToWorld,
  snapOrigin,
  trimForArrow,
} from '../lib/geometry'
import { edgeId } from '../lib/ids'
import { NodeView } from './NodeView'
import { EdgeView } from './EdgeView'
import type { Tool } from './Toolbar'
import './Canvas.css'

export interface Editing {
  type: 'node' | 'edge'
  id: string
}

interface CanvasProps {
  diagram: Diagram
  history: History<Diagram>
  selection: Selection
  onSelectionChange: (s: Selection) => void
  viewport: Viewport
  onViewportChange: (next: Viewport) => void
  edgeStyle: EdgeStyle
  snapToGrid: boolean
  tool: Tool
  spaceHeld: boolean
  editing: Editing | null
  onEditingChange: (e: Editing | null) => void
  onSizeChange: (size: { w: number; h: number }) => void
  svgRef: React.RefObject<SVGSVGElement | null>
}

type Interaction =
  | { type: 'idle' }
  | { type: 'pan'; startClient: Point; startViewport: Viewport }
  | { type: 'marquee'; start: Point; current: Point; additive: boolean }
  | {
      type: 'move'
      nodeIds: string[]
      startPositions: Map<string, Point>
      startWorld: Point
      snapshot: Diagram
      moved: boolean
      toggleOnRelease: string | null
    }
  | {
      type: 'connect'
      sourceId: string
      sourcePort: PortSide
      current: Point
      target: { nodeId: string; port: PortSide } | null
    }

const IDLE: Interaction = { type: 'idle' }
const DOUBLE_CLICK_MS = 450

export function Canvas(props: CanvasProps) {
  const {
    diagram,
    history,
    selection,
    onSelectionChange,
    viewport,
    onViewportChange,
    edgeStyle,
    snapToGrid,
    tool,
    spaceHeld,
    editing,
    onEditingChange,
    onSizeChange,
    svgRef,
  } = props

  const wrapRef = useRef<HTMLDivElement>(null)
  const [interaction, setInteractionState] = useState<Interaction>(IDLE)
  const interactionRef = useRef<Interaction>(IDLE)
  const lastTapRef = useRef<{ id: string; time: number } | null>(null)
  const setInteraction = useCallback((next: Interaction) => {
    interactionRef.current = next
    setInteractionState(next)
  }, [])

  const viewportRef = useRef(viewport)
  const diagramRef = useRef(diagram)
  const selectionRef = useRef(selection)
  useLayoutEffect(() => {
    viewportRef.current = viewport
    diagramRef.current = diagram
    selectionRef.current = selection
  })

  useLayoutEffect(() => {
    const el = wrapRef.current
    if (!el) return
    const report = () => onSizeChange({ w: el.clientWidth, h: el.clientHeight })
    report()
    const ro = new ResizeObserver(report)
    ro.observe(el)
    return () => ro.disconnect()
  }, [onSizeChange])

  const clientToWorld = useCallback(
    (clientX: number, clientY: number): Point => {
      const rect = svgRef.current?.getBoundingClientRect()
      const local = { x: clientX - (rect?.left ?? 0), y: clientY - (rect?.top ?? 0) }
      return screenToWorld(local, viewportRef.current)
    },
    [svgRef],
  )

  // Wheel zoom needs a non-passive listener so the page never scrolls/zooms.
  useEffect(() => {
    const svg = svgRef.current
    if (!svg) return
    const onWheel = (e: WheelEvent) => {
      e.preventDefault()
      const rect = svg.getBoundingClientRect()
      const local = { x: e.clientX - rect.left, y: e.clientY - rect.top }
      const vp = viewportRef.current
      const factor = Math.exp(-e.deltaY * (e.deltaMode === 1 ? 0.05 : 0.0015))
      const zoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, vp.zoom * factor))
      const world = screenToWorld(local, vp)
      onViewportChange({ zoom, x: local.x - world.x * zoom, y: local.y - world.y * zoom })
    }
    svg.addEventListener('wheel', onWheel, { passive: false })
    return () => svg.removeEventListener('wheel', onWheel)
  }, [onViewportChange, svgRef])

  const findTarget = (p: Point, excludeId: string) => {
    const nodes = diagramRef.current.nodes
    for (let i = nodes.length - 1; i >= 0; i--) {
      const n = nodes[i]
      if (n.id !== excludeId && pointInNode(n, p, 18)) return { nodeId: n.id, port: nearestPort(n, p) }
    }
    return null
  }

  const onPointerDown = (e: React.PointerEvent<SVGSVGElement>) => {
    if (editing) return
    const svg = svgRef.current
    if (!svg) return
    const target = e.target as Element
    const wantsPan = e.button === 1 || spaceHeld || tool === 'pan'
    if (e.button !== 0 && e.button !== 1) return
    if (e.button === 1) e.preventDefault()
    svg.setPointerCapture(e.pointerId)

    if (wantsPan) {
      setInteraction({ type: 'pan', startClient: { x: e.clientX, y: e.clientY }, startViewport: viewportRef.current })
      return
    }

    const world = clientToWorld(e.clientX, e.clientY)
    const portEl = target.closest<SVGElement>('[data-port]')
    const nodeEl = target.closest<SVGElement>('[data-node-id]')
    const edgeEl = target.closest<SVGElement>('[data-edge-id]')

    // Pointer capture retargets the native dblclick to the <svg>, so detect double-clicks here instead.
    const tapId = portEl ? null : nodeEl ? `node:${nodeEl.dataset.nodeId}` : edgeEl ? `edge:${edgeEl.dataset.edgeId}` : null
    const last = lastTapRef.current
    lastTapRef.current = tapId ? { id: tapId, time: e.timeStamp } : null
    if (tapId && last && last.id === tapId && e.timeStamp - last.time < DOUBLE_CLICK_MS) {
      lastTapRef.current = null
      // Cancelling pointerdown suppresses the compat mousedown, which would otherwise steal focus from the editor.
      e.preventDefault()
      svg.releasePointerCapture(e.pointerId)
      const [type, id] = tapId.split(':') as ['node' | 'edge', string]
      onEditingChange({ type, id })
      return
    }

    if (portEl && nodeEl) {
      const sourceId = nodeEl.dataset.nodeId as string
      const sourcePort = portEl.dataset.port as PortSide
      onSelectionChange({ nodes: [sourceId], edges: [] })
      setInteraction({ type: 'connect', sourceId, sourcePort, current: world, target: null })
      return
    }

    if (nodeEl) {
      const id = nodeEl.dataset.nodeId as string
      const cur = selectionRef.current
      let nodeIds: string[]
      let toggleOnRelease: string | null = null
      if (cur.nodes.includes(id)) {
        nodeIds = cur.nodes
        if (e.shiftKey) toggleOnRelease = id
      } else {
        nodeIds = e.shiftKey ? [...cur.nodes, id] : [id]
        onSelectionChange({ nodes: nodeIds, edges: e.shiftKey ? cur.edges : [] })
      }
      const startPositions = new Map<string, Point>()
      for (const n of diagramRef.current.nodes) if (nodeIds.includes(n.id)) startPositions.set(n.id, { x: n.x, y: n.y })
      setInteraction({
        type: 'move',
        nodeIds,
        startPositions,
        startWorld: world,
        snapshot: diagramRef.current,
        moved: false,
        toggleOnRelease,
      })
      return
    }

    if (edgeEl) {
      const id = edgeEl.dataset.edgeId as string
      const cur = selectionRef.current
      if (e.shiftKey) {
        const edges = cur.edges.includes(id) ? cur.edges.filter((x) => x !== id) : [...cur.edges, id]
        onSelectionChange({ nodes: cur.nodes, edges })
      } else {
        onSelectionChange({ nodes: [], edges: [id] })
      }
      return
    }

    if (!e.shiftKey) onSelectionChange({ nodes: [], edges: [] })
    setInteraction({ type: 'marquee', start: world, current: world, additive: e.shiftKey })
  }

  const onPointerMove = (e: React.PointerEvent<SVGSVGElement>) => {
    const it = interactionRef.current
    if (it.type === 'idle') return
    switch (it.type) {
      case 'pan': {
        onViewportChange({
          ...it.startViewport,
          x: it.startViewport.x + (e.clientX - it.startClient.x),
          y: it.startViewport.y + (e.clientY - it.startClient.y),
        })
        return
      }
      case 'marquee': {
        setInteraction({ ...it, current: clientToWorld(e.clientX, e.clientY) })
        return
      }
      case 'move': {
        const world = clientToWorld(e.clientX, e.clientY)
        const dx = world.x - it.startWorld.x
        const dy = world.y - it.startWorld.y
        if (!it.moved && Math.hypot(dx, dy) * viewportRef.current.zoom < 3) return
        const moved: Interaction = { ...it, moved: true }
        interactionRef.current = moved
        history.replace((d) => ({
          ...d,
          nodes: d.nodes.map((n) => {
            const start = it.startPositions.get(n.id)
            if (!start) return n
            return { ...n, ...snapOrigin(start.x + dx, start.y + dy, n.w, n.h, snapToGrid) }
          }),
        }))
        return
      }
      case 'connect': {
        const world = clientToWorld(e.clientX, e.clientY)
        setInteraction({ ...it, current: world, target: findTarget(world, it.sourceId) })
        return
      }
    }
  }

  const onPointerUp = (e: React.PointerEvent<SVGSVGElement>) => {
    const it = interactionRef.current
    const svg = svgRef.current
    if (svg?.hasPointerCapture(e.pointerId)) svg.releasePointerCapture(e.pointerId)
    if (it.type === 'idle') return
    setInteraction(IDLE)
    switch (it.type) {
      case 'move': {
        if (it.moved) {
          history.record(it.snapshot)
        } else if (it.toggleOnRelease) {
          const cur = selectionRef.current
          onSelectionChange({ ...cur, nodes: cur.nodes.filter((id) => id !== it.toggleOnRelease) })
        }
        return
      }
      case 'marquee': {
        const rect = normalizeRect(it.start, it.current)
        if (rect.w * viewportRef.current.zoom < 4 && rect.h * viewportRef.current.zoom < 4) return
        const hit = diagramRef.current.nodes.filter((n) => rectsIntersect(rect, n)).map((n) => n.id)
        const cur = selectionRef.current
        const nodes = it.additive ? Array.from(new Set([...cur.nodes, ...hit])) : hit
        const nodeSet = new Set(nodes)
        const edges = diagramRef.current.edges
          .filter((ed) => nodeSet.has(ed.source) && nodeSet.has(ed.target))
          .map((ed) => ed.id)
        onSelectionChange({ nodes, edges: it.additive ? Array.from(new Set([...cur.edges, ...edges])) : edges })
        return
      }
      case 'connect': {
        if (!it.target) return
        const { nodeId, port } = it.target
        const edge: FlowEdge = {
          id: edgeId(),
          source: it.sourceId,
          sourcePort: it.sourcePort,
          target: nodeId,
          targetPort: port,
          label: '',
        }
        history.commit((d) => ({ ...d, edges: [...d.edges, edge] }))
        onSelectionChange({ nodes: [], edges: [edge.id] })
        return
      }
      default:
        return
    }
  }

  const cursorClass =
    interaction.type === 'pan'
      ? 'is-panning'
      : spaceHeld || tool === 'pan'
        ? 'can-pan'
        : interaction.type === 'connect'
          ? 'is-connecting'
          : interaction.type === 'marquee'
            ? 'is-marquee'
            : ''

  const selectedNodes = new Set(selection.nodes)
  const selectedEdges = new Set(selection.edges)
  const transform = `translate(${viewport.x} ${viewport.y}) scale(${viewport.zoom})`

  let connectPreview: { d: string; arrow: string } | null = null
  if (interaction.type === 'connect') {
    const source = diagram.nodes.find((n) => n.id === interaction.sourceId)
    if (source) {
      const s = portPosition(source, interaction.sourcePort)
      let points: Point[]
      if (interaction.target) {
        const t = diagram.nodes.find((n) => n.id === interaction.target?.nodeId)
        points = t ? routeEdge(source, interaction.sourcePort, t, interaction.target.port, edgeStyle) : [s, interaction.current]
      } else {
        points = routePoints(s, interaction.sourcePort, interaction.current, oppositeOf(interaction.sourcePort), 'straight')
      }
      connectPreview = { d: polylinePath(trimForArrow(points)), arrow: arrowHead(points) }
    }
  }

  const marqueeRect: Rect | null = interaction.type === 'marquee' ? normalizeRect(interaction.start, interaction.current) : null

  return (
    <div ref={wrapRef} className={`canvas-wrap ${cursorClass}`}>
      <svg
        ref={svgRef}
        className="canvas"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onContextMenu={(e) => e.preventDefault()}
      >
        <defs>
          <pattern
            id="grid-dots"
            width={GRID}
            height={GRID}
            patternUnits="userSpaceOnUse"
            patternTransform={transform}
          >
            <circle cx={GRID / 2} cy={GRID / 2} r={1.1} className="grid-dot" />
          </pattern>
          <filter id="node-shadow" x="-10%" y="-10%" width="120%" height="130%">
            <feDropShadow dx="0" dy="1" stdDeviation="1.5" floodColor="#0f172a" floodOpacity="0.08" />
          </filter>
        </defs>
        <rect className="canvas-bg" width="100%" height="100%" fill="url(#grid-dots)" data-bg="true" />
        <g transform={transform}>
          <g className="edges">
            {diagram.edges.map((edge) => {
              const ends = edgeEndpoints(diagram, edge)
              if (!ends) return null
              return (
                <EdgeView
                  key={edge.id}
                  edge={edge}
                  source={ends[0]}
                  target={ends[1]}
                  style={edgeStyle}
                  selected={selectedEdges.has(edge.id)}
                  editing={editing?.type === 'edge' && editing.id === edge.id}
                />
              )
            })}
          </g>
          {connectPreview && (
            <g className="edge edge-preview">
              <path className="edge-line" d={connectPreview.d} />
              <polygon className="edge-arrow" points={connectPreview.arrow} />
            </g>
          )}
          <g className="nodes">
            {diagram.nodes.map((node) => (
              <NodeView
                key={node.id}
                node={node}
                selected={selectedNodes.has(node.id)}
                editing={editing?.type === 'node' && editing.id === node.id}
                targetPort={
                  interaction.type === 'connect' && interaction.target?.nodeId === node.id ? interaction.target.port : null
                }
                connecting={interaction.type === 'connect'}
              />
            ))}
          </g>
          {marqueeRect && (
            <rect
              className="marquee"
              x={marqueeRect.x}
              y={marqueeRect.y}
              width={marqueeRect.w}
              height={marqueeRect.h}
              vectorEffect="non-scaling-stroke"
            />
          )}
        </g>
      </svg>
      {diagram.nodes.length === 0 && interaction.type === 'idle' && (
        <div className="canvas-empty">
          <div className="canvas-empty-card">
            <span className="canvas-empty-title">Start with a shape</span>
            <span className="canvas-empty-sub">Drag one in from the palette, then drag between ports to connect.</span>
            <span className="canvas-empty-keys">
              Press <kbd>?</kbd> for keyboard shortcuts
            </span>
          </div>
        </div>
      )}
      {editing && (
        <LabelEditor
          key={`${editing.type}-${editing.id}`}
          editing={editing}
          diagram={diagram}
          viewport={viewport}
          edgeStyle={edgeStyle}
          onCommit={(value) => {
            const trimmed = value.trim()
            if (editing.type === 'node') {
              history.commit((d) => ({
                ...d,
                nodes: d.nodes.map((n) => (n.id === editing.id ? { ...n, label: trimmed || n.label } : n)),
              }))
            } else {
              history.commit((d) => ({
                ...d,
                edges: d.edges.map((ed) => (ed.id === editing.id ? { ...ed, label: trimmed } : ed)),
              }))
            }
            onEditingChange(null)
          }}
          onCancel={() => onEditingChange(null)}
        />
      )}
    </div>
  )
}

function oppositeOf(side: PortSide): PortSide {
  switch (side) {
    case 'top':
      return 'bottom'
    case 'bottom':
      return 'top'
    case 'left':
      return 'right'
    case 'right':
      return 'left'
  }
}

interface LabelEditorProps {
  editing: Editing
  diagram: Diagram
  viewport: Viewport
  edgeStyle: EdgeStyle
  onCommit: (value: string) => void
  onCancel: () => void
}

function LabelEditor({ editing, diagram, viewport, edgeStyle, onCommit, onCancel }: LabelEditorProps) {
  const inputRef = useRef<HTMLInputElement>(null)
  const committed = useRef(false)

  let initial = ''
  let center: Point = { x: 0, y: 0 }
  let width = 160
  let node: FlowNode | undefined
  if (editing.type === 'node') {
    node = diagram.nodes.find((n) => n.id === editing.id)
    if (node) {
      initial = node.label
      center = { x: node.x + node.w / 2, y: node.y + node.h / 2 }
      width = Math.max(120, node.w - 24)
    }
  } else {
    const edge = diagram.edges.find((e) => e.id === editing.id)
    const ends = edge ? edgeEndpoints(diagram, edge) : null
    if (edge && ends) {
      initial = edge.label
      center = polylineMidpoint(routeEdge(ends[0], edge.sourcePort, ends[1], edge.targetPort, edgeStyle))
      width = 140
    }
  }

  const [value, setValue] = useState(initial)

  useEffect(() => {
    const el = inputRef.current
    if (!el) return
    el.focus()
    el.select()
  }, [])

  const commit = () => {
    if (committed.current) return
    committed.current = true
    onCommit(value)
  }

  const screen = { x: center.x * viewport.zoom + viewport.x, y: center.y * viewport.zoom + viewport.y }
  const scaledWidth = width * viewport.zoom

  return (
    <div
      className={`label-editor label-editor-${editing.type}`}
      style={{ left: screen.x, top: screen.y, width: Math.max(140, scaledWidth) }}
    >
      <input
        ref={inputRef}
        value={value}
        placeholder={editing.type === 'edge' ? 'Edge label' : 'Label'}
        aria-label={editing.type === 'edge' ? 'Edge label' : 'Node label'}
        onChange={(e) => setValue(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => {
          e.stopPropagation()
          if (e.key === 'Enter') commit()
          if (e.key === 'Escape') {
            committed.current = true
            onCancel()
          }
        }}
      />
    </div>
  )
}
