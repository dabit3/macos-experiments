import { NODE_KINDS, PORT_SIDES, kindMeta } from '../types'
import type { Diagram, EdgeStyle, FlowEdge, FlowNode, NodeKind, PortSide } from '../types'
import {
  arrowHead,
  diagramBounds,
  edgeEndpoints,
  polylineMidpoint,
  polylinePath,
  routeEdge,
  shapePath,
  trimForArrow,
  wrapLabel,
} from './geometry'

export const FILE_VERSION = 1

export interface DiagramFile {
  app: 'flowchart-studio'
  version: number
  edgeStyle: EdgeStyle
  diagram: Diagram
}

export function toJSON(diagram: Diagram, edgeStyle: EdgeStyle): string {
  const file: DiagramFile = { app: 'flowchart-studio', version: FILE_VERSION, edgeStyle, diagram }
  return JSON.stringify(file, null, 2)
}

const KIND_SET = new Set<string>(NODE_KINDS.map((k) => k.kind))
const PORT_SET = new Set<string>(PORT_SIDES)

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null
}

function num(v: unknown, fallback: number): number {
  return typeof v === 'number' && Number.isFinite(v) ? v : fallback
}

function parseNode(raw: unknown): FlowNode | null {
  if (!isRecord(raw) || typeof raw.id !== 'string') return null
  const kind: NodeKind = typeof raw.kind === 'string' && KIND_SET.has(raw.kind) ? (raw.kind as NodeKind) : 'process'
  const meta = kindMeta(kind)
  return {
    id: raw.id,
    kind,
    x: num(raw.x, 0),
    y: num(raw.y, 0),
    w: num(raw.w, meta.w),
    h: num(raw.h, meta.h),
    label: typeof raw.label === 'string' ? raw.label : meta.defaultLabel,
  }
}

function parseEdge(raw: unknown, nodeIds: Set<string>): FlowEdge | null {
  if (!isRecord(raw) || typeof raw.id !== 'string') return null
  if (typeof raw.source !== 'string' || typeof raw.target !== 'string') return null
  if (!nodeIds.has(raw.source) || !nodeIds.has(raw.target)) return null
  const sp: PortSide = typeof raw.sourcePort === 'string' && PORT_SET.has(raw.sourcePort) ? (raw.sourcePort as PortSide) : 'bottom'
  const tp: PortSide = typeof raw.targetPort === 'string' && PORT_SET.has(raw.targetPort) ? (raw.targetPort as PortSide) : 'top'
  return {
    id: raw.id,
    source: raw.source,
    sourcePort: sp,
    target: raw.target,
    targetPort: tp,
    label: typeof raw.label === 'string' ? raw.label : '',
  }
}

export function fromJSON(text: string): { diagram: Diagram; edgeStyle?: EdgeStyle } {
  const parsed: unknown = JSON.parse(text)
  if (!isRecord(parsed)) throw new Error('Not a Flowchart Studio file')
  const body = isRecord(parsed.diagram) ? parsed.diagram : parsed
  if (!Array.isArray(body.nodes)) throw new Error('File has no nodes array')
  const nodes: FlowNode[] = []
  const seen = new Set<string>()
  for (const raw of body.nodes) {
    const n = parseNode(raw)
    if (n && !seen.has(n.id)) {
      nodes.push(n)
      seen.add(n.id)
    }
  }
  const edges: FlowEdge[] = []
  if (Array.isArray(body.edges)) {
    for (const raw of body.edges) {
      const e = parseEdge(raw, seen)
      if (e) edges.push(e)
    }
  }
  const edgeStyle =
    parsed.edgeStyle === 'straight' || parsed.edgeStyle === 'orthogonal' ? (parsed.edgeStyle as EdgeStyle) : undefined
  return { diagram: { nodes, edges }, edgeStyle }
}

function esc(text: string): string {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

const SVG_FONT = "'Inter Variable', 'Inter', 'Segoe UI', system-ui, -apple-system, Roboto, sans-serif"

export function toSVG(diagram: Diagram, edgeStyle: EdgeStyle): string {
  const bounds = diagramBounds(diagram, 48) ?? { x: 0, y: 0, w: 400, h: 240 }
  const parts: string[] = []
  parts.push(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${bounds.x} ${bounds.y} ${bounds.w} ${bounds.h}" width="${bounds.w}" height="${bounds.h}" font-family="${SVG_FONT}">`,
  )
  parts.push(`<title>Flowchart Studio export</title>`)
  parts.push(`<rect x="${bounds.x}" y="${bounds.y}" width="${bounds.w}" height="${bounds.h}" fill="#ffffff"/>`)

  parts.push('<g class="edges" fill="none" stroke="#5c667a" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">')
  for (const edge of diagram.edges) {
    const ends = edgeEndpoints(diagram, edge)
    if (!ends) continue
    const points = routeEdge(ends[0], edge.sourcePort, ends[1], edge.targetPort, edgeStyle)
    parts.push(`<path d="${polylinePath(trimForArrow(points))}"/>`)
    parts.push(`<polygon points="${arrowHead(points)}" fill="#5c667a" stroke="none"/>`)
    if (edge.label) {
      const mid = polylineMidpoint(points)
      const w = edge.label.length * 7.5 + 16
      parts.push(
        `<rect x="${mid.x - w / 2}" y="${mid.y - 11}" width="${w}" height="22" rx="6" fill="#ffffff" stroke="#c9cfd8" stroke-width="1"/>`,
      )
      parts.push(
        `<text x="${mid.x}" y="${mid.y}" fill="#0f172a" stroke="none" font-size="12" font-weight="600" text-anchor="middle" dominant-baseline="central">${esc(edge.label)}</text>`,
      )
    }
  }
  parts.push('</g>')

  parts.push('<g class="nodes">')
  for (const node of diagram.nodes) {
    const meta = kindMeta(node.kind)
    parts.push(`<g class="node node-${node.kind}" data-id="${esc(node.id)}">`)
    parts.push(`<path d="${shapePath(node)}" fill="#ffffff" stroke="${meta.color}" stroke-width="1.5"/>`)
    const lines = wrapLabel(node.label, node.kind === 'decision' ? 14 : 18)
    const lineH = 17
    const startY = node.y + node.h / 2 - ((lines.length - 1) * lineH) / 2
    parts.push(
      `<text x="${node.x + node.w / 2}" y="${startY}" fill="#0f172a" font-size="13.5" font-weight="550" text-anchor="middle" dominant-baseline="central">`,
    )
    lines.forEach((line, i) => {
      parts.push(`<tspan x="${node.x + node.w / 2}" dy="${i === 0 ? 0 : lineH}">${esc(line)}</tspan>`)
    })
    parts.push('</text></g>')
  }
  parts.push('</g>')
  parts.push('</svg>')
  return parts.join('\n')
}

export function downloadFile(filename: string, contents: string, mime: string): void {
  const blob = new Blob([contents], { type: mime })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
