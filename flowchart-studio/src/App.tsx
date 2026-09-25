import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { EMPTY_SELECTION, GRID, MAX_ZOOM, MIN_ZOOM, kindMeta } from './types'
import type { Diagram, EdgeStyle, FlowEdge, FlowNode, NodeKind, Point, Selection, Viewport } from './types'
import { useHistory } from './hooks/useHistory'
import { diagramBounds, screenToWorld, snapOrigin } from './lib/geometry'
import { layeredLayout } from './lib/layout'
import { edgeId, nodeId, seedIds } from './lib/ids'
import { downloadFile, fromJSON, toJSON, toSVG } from './lib/serialize'
import { Canvas } from './components/Canvas'
import type { Editing } from './components/Canvas'
import { Palette } from './components/Palette'
import { Toolbar } from './components/Toolbar'
import type { Tool } from './components/Toolbar'
import { Minimap } from './components/Minimap'
import { Inspector } from './components/Inspector'
import { Icon, ShapeIcon } from './components/Icons'
import { Shortcuts } from './components/Shortcuts'
import './App.css'

const STORAGE_KEY = 'flowchart-studio:document'
const EMPTY: Diagram = { nodes: [], edges: [] }

interface StoredDoc {
  diagram: Diagram
  edgeStyle: EdgeStyle
  snapToGrid: boolean
}

function loadStored(): StoredDoc {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return { diagram: EMPTY, edgeStyle: 'orthogonal', snapToGrid: true }
    const parsed = fromJSON(raw)
    const obj = JSON.parse(raw) as { snapToGrid?: unknown }
    return {
      diagram: parsed.diagram,
      edgeStyle: parsed.edgeStyle ?? 'orthogonal',
      snapToGrid: typeof obj.snapToGrid === 'boolean' ? obj.snapToGrid : true,
    }
  } catch {
    return { diagram: EMPTY, edgeStyle: 'orthogonal', snapToGrid: true }
  }
}

function fitViewport(target: Diagram, size: { w: number; h: number }): Viewport {
  const bounds = diagramBounds(target, 60)
  if (!bounds) return { x: size.w / 2, y: size.h / 2, zoom: 1 }
  const zoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, Math.min(size.w / bounds.w, size.h / bounds.h, 1.5)))
  return {
    zoom,
    x: (size.w - bounds.w * zoom) / 2 - bounds.x * zoom,
    y: (size.h - bounds.h * zoom) / 2 - bounds.y * zoom,
  }
}

interface PaletteDrag {
  kind: NodeKind
  client: Point
  startClient: Point
}

function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false
  return target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT' || target.isContentEditable
}

export default function App() {
  const [stored] = useState(loadStored)
  const history = useHistory<Diagram>(stored.diagram)
  const diagram = history.state
  const [edgeStyle, setEdgeStyle] = useState<EdgeStyle>(stored.edgeStyle)
  const [snapToGrid, setSnapToGrid] = useState(stored.snapToGrid)
  const [tool, setTool] = useState<Tool>('select')
  const [rawSelection, setSelection] = useState<Selection>(EMPTY_SELECTION)
  const [viewport, setViewport] = useState<Viewport>({ x: 0, y: 0, zoom: 1 })
  const [canvasSize, setCanvasSize] = useState({ w: 800, h: 600 })
  const [spaceHeld, setSpaceHeld] = useState(false)
  const [editing, setEditing] = useState<Editing | null>(null)
  const [paletteDrag, setPaletteDrag] = useState<PaletteDrag | null>(null)
  const [toast, setToast] = useState<string | null>(null)
  const [showShortcuts, setShowShortcuts] = useState(false)
  const closeShortcuts = useCallback(() => setShowShortcuts(false), [])
  const svgRef = useRef<SVGSVGElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const toastTimer = useRef<number | null>(null)
  const initialFit = useRef(false)

  useEffect(() => {
    seedIds(diagram)
  }, [diagram])

  // Autosave.
  useEffect(() => {
    const doc = { ...JSON.parse(toJSON(diagram, edgeStyle)), snapToGrid }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(doc))
  }, [diagram, edgeStyle, snapToGrid])

  // Ignore selected ids that no longer exist (undo, import, delete).
  const selection = useMemo<Selection>(() => {
    const nodeIds = new Set(diagram.nodes.map((n) => n.id))
    const edgeIds = new Set(diagram.edges.map((e) => e.id))
    const nodes = rawSelection.nodes.filter((id) => nodeIds.has(id))
    const edges = rawSelection.edges.filter((id) => edgeIds.has(id))
    return nodes.length === rawSelection.nodes.length && edges.length === rawSelection.edges.length
      ? rawSelection
      : { nodes, edges }
  }, [diagram, rawSelection])

  const showToast = useCallback((message: string) => {
    setToast(message)
    if (toastTimer.current) window.clearTimeout(toastTimer.current)
    toastTimer.current = window.setTimeout(() => setToast(null), 2800)
  }, [])

  const fitToView = useCallback(
    (target: Diagram = diagram, size = canvasSize) => setViewport(fitViewport(target, size)),
    [diagram, canvasSize],
  )

  const onSizeChange = useCallback(
    (size: { w: number; h: number }) => {
      setCanvasSize((prev) => (prev.w === size.w && prev.h === size.h ? prev : size))
      if (initialFit.current || size.w <= 0) return
      initialFit.current = true
      if (stored.diagram.nodes.length > 0) setViewport(fitViewport(stored.diagram, size))
      else setViewport({ x: GRID * 2, y: GRID * 2, zoom: 1 })
    },
    [stored],
  )

  const zoomBy = useCallback(
    (factor: number) => {
      setViewport((vp) => {
        const zoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, vp.zoom * factor))
        const cx = canvasSize.w / 2
        const cy = canvasSize.h / 2
        const world = screenToWorld({ x: cx, y: cy }, vp)
        return { zoom, x: cx - world.x * zoom, y: cy - world.y * zoom }
      })
    },
    [canvasSize],
  )

  const deleteSelection = useCallback(() => {
    if (selection.nodes.length === 0 && selection.edges.length === 0) return
    const nodeSet = new Set(selection.nodes)
    const edgeSet = new Set(selection.edges)
    history.commit((d) => ({
      nodes: d.nodes.filter((n) => !nodeSet.has(n.id)),
      edges: d.edges.filter((e) => !edgeSet.has(e.id) && !nodeSet.has(e.source) && !nodeSet.has(e.target)),
    }))
    setSelection(EMPTY_SELECTION)
    setEditing(null)
  }, [history, selection])

  const duplicateSelection = useCallback(() => {
    if (selection.nodes.length === 0) return
    const nodeSet = new Set(selection.nodes)
    const idMap = new Map<string, string>()
    const newNodes: FlowNode[] = []
    for (const n of diagram.nodes) {
      if (!nodeSet.has(n.id)) continue
      const id = nodeId()
      idMap.set(n.id, id)
      newNodes.push({ ...n, id, x: n.x + GRID * 2, y: n.y + GRID * 2 })
    }
    const newEdges: FlowEdge[] = diagram.edges
      .filter((e) => nodeSet.has(e.source) && nodeSet.has(e.target))
      .map((e) => ({
        ...e,
        id: edgeId(),
        source: idMap.get(e.source) as string,
        target: idMap.get(e.target) as string,
      }))
    history.commit((d) => ({ nodes: [...d.nodes, ...newNodes], edges: [...d.edges, ...newEdges] }))
    setSelection({ nodes: newNodes.map((n) => n.id), edges: newEdges.map((e) => e.id) })
    showToast(`Duplicated ${newNodes.length} node${newNodes.length === 1 ? '' : 's'}`)
  }, [diagram, history, selection, showToast])

  const selectAll = useCallback(() => {
    setSelection({ nodes: diagram.nodes.map((n) => n.id), edges: diagram.edges.map((e) => e.id) })
  }, [diagram])

  const autoLayout = useCallback(() => {
    if (diagram.nodes.length === 0) return
    const next = layeredLayout(diagram)
    history.commit(next)
    fitToView(next, canvasSize)
    showToast('Auto layout applied')
  }, [diagram, history, fitToView, canvasSize, showToast])

  const exportSVG = useCallback(() => {
    downloadFile('flowchart.svg', toSVG(diagram, edgeStyle), 'image/svg+xml')
    showToast('Downloaded flowchart.svg')
  }, [diagram, edgeStyle, showToast])

  const exportJSON = useCallback(() => {
    downloadFile('flowchart.json', toJSON(diagram, edgeStyle), 'application/json')
    showToast('Downloaded flowchart.json')
  }, [diagram, edgeStyle, showToast])

  const importFile = useCallback(
    async (file: File) => {
      try {
        const parsed = fromJSON(await file.text())
        history.commit(parsed.diagram)
        if (parsed.edgeStyle) setEdgeStyle(parsed.edgeStyle)
        setSelection(EMPTY_SELECTION)
        fitToView(parsed.diagram, canvasSize)
        showToast(`Imported ${parsed.diagram.nodes.length} nodes, ${parsed.diagram.edges.length} edges`)
      } catch (err) {
        showToast(`Import failed: ${err instanceof Error ? err.message : 'invalid file'}`)
      }
    },
    [history, fitToView, canvasSize, showToast],
  )

  const newDiagram = useCallback(() => {
    if (diagram.nodes.length === 0) return
    history.commit(EMPTY)
    setSelection(EMPTY_SELECTION)
    setViewport({ x: GRID * 2, y: GRID * 2, zoom: 1 })
    showToast('Canvas cleared (Ctrl+Z to undo)')
  }, [diagram, history, showToast])

  const addNodeAt = useCallback(
    (kind: NodeKind, world: Point) => {
      const meta = kindMeta(kind)
      const node: FlowNode = {
        id: nodeId(),
        kind,
        ...snapOrigin(world.x - meta.w / 2, world.y - meta.h / 2, meta.w, meta.h, snapToGrid),
        w: meta.w,
        h: meta.h,
        label: meta.defaultLabel,
      }
      history.commit((d) => ({ ...d, nodes: [...d.nodes, node] }))
      setSelection({ nodes: [node.id], edges: [] })
      return node
    },
    [history, snapToGrid],
  )

  // Palette drag: ghost follows the pointer; drop over the canvas creates a node.
  const onPaletteDragStart = useCallback((kind: NodeKind, e: React.PointerEvent) => {
    const client = { x: e.clientX, y: e.clientY }
    setPaletteDrag({ kind, client, startClient: client })
  }, [])

  useEffect(() => {
    if (!paletteDrag) return
    const onMove = (e: PointerEvent) => {
      setPaletteDrag((d) => (d ? { ...d, client: { x: e.clientX, y: e.clientY } } : d))
    }
    const onUp = (e: PointerEvent) => {
      const svg = svgRef.current
      const drag = paletteDrag
      setPaletteDrag(null)
      if (!svg) return
      const rect = svg.getBoundingClientRect()
      const inside = e.clientX >= rect.left && e.clientX <= rect.right && e.clientY >= rect.top && e.clientY <= rect.bottom
      const moved = Math.hypot(e.clientX - drag.startClient.x, e.clientY - drag.startClient.y) > 4
      if (inside) {
        addNodeAt(drag.kind, screenToWorld({ x: e.clientX - rect.left, y: e.clientY - rect.top }, viewport))
      } else if (!moved) {
        // A plain click drops the node in the middle of the current view.
        addNodeAt(drag.kind, screenToWorld({ x: canvasSize.w / 2, y: canvasSize.h / 2 }, viewport))
      }
    }
    window.addEventListener('pointermove', onMove)
    window.addEventListener('pointerup', onUp, { once: true })
    return () => {
      window.removeEventListener('pointermove', onMove)
      window.removeEventListener('pointerup', onUp)
    }
  }, [paletteDrag, addNodeAt, viewport, canvasSize])

  // Keyboard shortcuts.
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (isEditableTarget(e.target)) return
      const mod = e.ctrlKey || e.metaKey
      if (e.code === 'Space') {
        e.preventDefault()
        setSpaceHeld(true)
        return
      }
      if (mod && e.key.toLowerCase() === 'z') {
        e.preventDefault()
        if (e.shiftKey) history.redo()
        else history.undo()
        return
      }
      if (mod && e.key.toLowerCase() === 'y') {
        e.preventDefault()
        history.redo()
        return
      }
      if (mod && e.key.toLowerCase() === 'd') {
        e.preventDefault()
        duplicateSelection()
        return
      }
      if (mod && e.key.toLowerCase() === 'a') {
        e.preventDefault()
        selectAll()
        return
      }
      if (mod && e.key.toLowerCase() === 's') {
        e.preventDefault()
        exportJSON()
        return
      }
      if (mod) return
      switch (e.key) {
        case 'Delete':
        case 'Backspace':
          e.preventDefault()
          deleteSelection()
          break
        case 'Escape':
          setSelection(EMPTY_SELECTION)
          setEditing(null)
          break
        case 'Enter':
          if (selection.nodes.length === 1 && selection.edges.length === 0) setEditing({ type: 'node', id: selection.nodes[0] })
          else if (selection.edges.length === 1 && selection.nodes.length === 0) setEditing({ type: 'edge', id: selection.edges[0] })
          break
        case 'v':
        case 'V':
          setTool('select')
          break
        case 'h':
        case 'H':
          setTool('pan')
          break
        case '+':
        case '=':
          zoomBy(1.2)
          break
        case '-':
        case '_':
          zoomBy(1 / 1.2)
          break
        case '!':
          fitToView()
          break
        case '?':
          setShowShortcuts(true)
          break
        default:
          break
      }
    }
    const onKeyUp = (e: KeyboardEvent) => {
      if (e.code === 'Space') setSpaceHeld(false)
    }
    const onBlur = () => setSpaceHeld(false)
    window.addEventListener('keydown', onKeyDown)
    window.addEventListener('keyup', onKeyUp)
    window.addEventListener('blur', onBlur)
    return () => {
      window.removeEventListener('keydown', onKeyDown)
      window.removeEventListener('keyup', onKeyUp)
      window.removeEventListener('blur', onBlur)
    }
  }, [history, duplicateSelection, deleteSelection, selectAll, exportJSON, zoomBy, fitToView, selection])

  const selectedNode =
    selection.nodes.length === 1 && selection.edges.length === 0
      ? (diagram.nodes.find((n) => n.id === selection.nodes[0]) ?? null)
      : null
  const selectedEdge =
    selection.edges.length === 1 && selection.nodes.length === 0
      ? (diagram.edges.find((e) => e.id === selection.edges[0]) ?? null)
      : null
  const hasSelection = selection.nodes.length > 0 || selection.edges.length > 0

  const ghostMeta = paletteDrag ? kindMeta(paletteDrag.kind) : null

  return (
    <div className={`app${paletteDrag ? ' is-palette-dragging' : ''}`}>
      <Toolbar
        tool={tool}
        onToolChange={setTool}
        edgeStyle={edgeStyle}
        onEdgeStyleChange={setEdgeStyle}
        snapToGrid={snapToGrid}
        onSnapChange={setSnapToGrid}
        canUndo={history.canUndo}
        canRedo={history.canRedo}
        onUndo={history.undo}
        onRedo={history.redo}
        hasSelection={hasSelection}
        onDuplicate={duplicateSelection}
        onDelete={deleteSelection}
        onAutoLayout={autoLayout}
        onImport={() => fileInputRef.current?.click()}
        onExportJSON={exportJSON}
        onExportSVG={exportSVG}
        onNew={newDiagram}
      />
      <div className="workspace">
        <Palette onDragStart={onPaletteDragStart} onShowShortcuts={() => setShowShortcuts(true)} />
        <div className="stage">
          <Canvas
            diagram={diagram}
            history={history}
            selection={selection}
            onSelectionChange={setSelection}
            viewport={viewport}
            onViewportChange={setViewport}
            edgeStyle={edgeStyle}
            snapToGrid={snapToGrid}
            tool={tool}
            spaceHeld={spaceHeld}
            editing={editing}
            onEditingChange={setEditing}
            onSizeChange={onSizeChange}
            svgRef={svgRef}
          />
          <Inspector
            key={selectedNode?.id ?? selectedEdge?.id ?? 'multi'}
            selection={selection}
            node={selectedNode}
            edge={selectedEdge}
            onLabelChange={(value) => {
              if (selectedNode) {
                const label = value.trim() || selectedNode.label
                history.commit((d) => ({ ...d, nodes: d.nodes.map((n) => (n.id === selectedNode.id ? { ...n, label } : n)) }))
              } else if (selectedEdge) {
                const label = value.trim()
                history.commit((d) => ({ ...d, edges: d.edges.map((e) => (e.id === selectedEdge.id ? { ...e, label } : e)) }))
              }
            }}
            onKindChange={(kind) => {
              if (!selectedNode) return
              const meta = kindMeta(kind)
              history.commit((d) => ({
                ...d,
                nodes: d.nodes.map((n) =>
                  n.id === selectedNode.id
                    ? { ...n, kind, w: meta.w, h: meta.h, x: n.x + (n.w - meta.w) / 2, y: n.y + (n.h - meta.h) / 2 }
                    : n,
                ),
              }))
            }}
            onDelete={deleteSelection}
            sourceLabel={selectedEdge ? diagram.nodes.find((n) => n.id === selectedEdge.source)?.label : undefined}
            targetLabel={selectedEdge ? diagram.nodes.find((n) => n.id === selectedEdge.target)?.label : undefined}
          />
          <Minimap diagram={diagram} viewport={viewport} canvasSize={canvasSize} onViewportChange={setViewport} />
          <div className="zoom-controls" role="group" aria-label="Zoom">
            <button type="button" className="zc-btn" title="Zoom out (−)" aria-label="Zoom out" onClick={() => zoomBy(1 / 1.2)} data-action="zoom-out">
              <Icon name="zoom-out" size={17} />
            </button>
            <button type="button" className="zc-value" title="Fit diagram to view (Shift+1)" onClick={() => fitToView()} data-action="zoom-fit">
              {Math.round(viewport.zoom * 100)}%
            </button>
            <button type="button" className="zc-btn" title="Zoom in (+)" aria-label="Zoom in" onClick={() => zoomBy(1.2)} data-action="zoom-in">
              <Icon name="zoom-in" size={17} />
            </button>
            <span className="zc-divider" />
            <button type="button" className="zc-btn" title="Fit to view (Shift+1)" aria-label="Fit to view" onClick={() => fitToView()} data-action="fit">
              <Icon name="fit" size={17} />
            </button>
          </div>
          {(hasSelection || spaceHeld || tool === 'pan') && (
            <div className="status-chip" role="status">
              {spaceHeld || tool === 'pan' ? (
                'Drag to pan the canvas'
              ) : (
                <>
                  {[
                    [selection.nodes.length, 'node'] as const,
                    [selection.edges.length, 'edge'] as const,
                  ]
                    .filter(([count]) => count > 0)
                    .map(([count, noun], i) => (
                      <span key={noun}>
                        {i > 0 && ' + '}
                        <b>{count}</b> {count === 1 ? noun : `${noun}s`}
                      </span>
                    ))}
                  {' selected'}
                </>
              )}
            </div>
          )}
          {toast && (
            <div className="toast" role="status">
              <Icon name="check" size={15} />
              {toast}
            </div>
          )}
        </div>
      </div>
      {paletteDrag && ghostMeta && (
        <div className="palette-ghost" style={{ left: paletteDrag.client.x, top: paletteDrag.client.y }}>
          <ShapeIcon kind={paletteDrag.kind} color={ghostMeta.color} />
          <span>{ghostMeta.name}</span>
        </div>
      )}
      {showShortcuts && <Shortcuts onClose={closeShortcuts} />}
      <input
        ref={fileInputRef}
        type="file"
        accept="application/json,.json"
        hidden
        onChange={(e) => {
          const file = e.target.files?.[0]
          if (file) void importFile(file)
          e.target.value = ''
        }}
      />
    </div>
  )
}
