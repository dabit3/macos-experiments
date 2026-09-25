import type { NodeKind } from '../types'

export type IconName =
  | 'select'
  | 'hand'
  | 'straight'
  | 'orthogonal'
  | 'grid'
  | 'layout'
  | 'zoom-in'
  | 'zoom-out'
  | 'fit'
  | 'undo'
  | 'redo'
  | 'import'
  | 'json'
  | 'svg'
  | 'trash'
  | 'new'
  | 'duplicate'
  | 'keyboard'
  | 'check'
  | 'close'

const PATHS: Record<IconName, React.ReactNode> = {
  select: <path d="M5 3l14 8-6 1.5L9.5 19 5 3z" />,
  hand: (
    <path d="M8 13V6a1.5 1.5 0 0 1 3 0v6M11 11V4.5a1.5 1.5 0 0 1 3 0V11M14 11V6a1.5 1.5 0 0 1 3 0v7M17 12.5a1.5 1.5 0 0 1 3 0V15a6 6 0 0 1-6 6h-2.5a6 6 0 0 1-5-2.7L4 14.3a1.6 1.6 0 0 1 2.6-1.8L8 14" />
  ),
  straight: (
    <>
      <path d="M5 19L19 5" />
      <path d="M13 5h6v6" />
    </>
  ),
  orthogonal: (
    <>
      <path d="M5 19v-7h14V5" />
      <path d="M15 5h4v4" />
    </>
  ),
  grid: (
    <>
      <path d="M4 9h16M4 15h16M9 4v16M15 4v16" />
    </>
  ),
  layout: (
    <>
      <rect x="9" y="3" width="6" height="4" rx="1" />
      <rect x="3" y="15" width="6" height="4" rx="1" />
      <rect x="15" y="15" width="6" height="4" rx="1" />
      <path d="M12 7v3M12 10H6v5M12 10h6v5" />
    </>
  ),
  'zoom-in': (
    <>
      <circle cx="11" cy="11" r="6.5" />
      <path d="M16 16l4 4M11 8.5v5M8.5 11h5" />
    </>
  ),
  'zoom-out': (
    <>
      <circle cx="11" cy="11" r="6.5" />
      <path d="M16 16l4 4M8.5 11h5" />
    </>
  ),
  fit: <path d="M4 9V5a1 1 0 0 1 1-1h4M15 4h4a1 1 0 0 1 1 1v4M20 15v4a1 1 0 0 1-1 1h-4M9 20H5a1 1 0 0 1-1-1v-4" />,
  undo: <path d="M8 7L4 11l4 4M4 11h10a5 5 0 0 1 0 10h-3" />,
  redo: <path d="M16 7l4 4-4 4M20 11H10a5 5 0 0 0 0 10h3" />,
  import: <path d="M12 4v11M7.5 10.5L12 15l4.5-4.5M4 17v2a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-2" />,
  json: <path d="M8 4c-2 0-3 1-3 3v3c0 1-.5 2-2 2 1.5 0 2 1 2 2v3c0 2 1 3 3 3M16 4c2 0 3 1 3 3v3c0 1 .5 2 2 2-1.5 0-2 1-2 2v3c0 2-1 3-3 3" />,
  svg: (
    <>
      <path d="M6 3h8l5 5v12a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z" />
      <path d="M14 3v5h5M8 16l2.5-4 2 3 1.5-2 2 3" />
    </>
  ),
  trash: <path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6" />,
  new: <path d="M12 5v14M5 12h14" />,
  keyboard: (
    <>
      <rect x="3" y="6" width="18" height="12" rx="2" />
      <path d="M7 10h.01M11 10h.01M15 10h.01M8 14h8" />
    </>
  ),
  check: <path d="M5 12.5l4.5 4.5L19 7.5" />,
  close: <path d="M6 6l12 12M18 6L6 18" />,
  duplicate: (
    <>
      <rect x="8" y="8" width="12" height="12" rx="2" />
      <path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3" />
    </>
  ),
}

/** Brand mark: solid tile with a single-weight flow glyph (node → elbow → node). */
export function Logo({ size = 28 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
      <rect width="32" height="32" rx="8" fill="var(--brand)" />
      <rect x="7" y="7" width="8" height="8" rx="2" fill="#fff" />
      <path d="M11 15v6a2.5 2.5 0 0 0 2.5 2.5H19" fill="none" stroke="#fff" strokeWidth="2.6" strokeLinecap="round" />
      <path d="M21 19l4.5 4.5L21 28l-4.5-4.5z" fill="#fff" />
    </svg>
  )
}

export function Icon({ name, size = 18 }: { name: IconName; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {PATHS[name]}
    </svg>
  )
}

export function ShapeIcon({ kind, color }: { kind: NodeKind; color: string }) {
  const fill = `${color}14`
  let shape: React.ReactNode
  switch (kind) {
    case 'start':
    case 'end':
      shape = <rect x="3" y="9" width="34" height="14" rx="7" />
      break
    case 'process':
      shape = <rect x="4" y="8" width="32" height="16" rx="3" />
      break
    case 'decision':
      shape = <path d="M20 4L36 16 20 28 4 16z" />
      break
    case 'data':
      shape = <path d="M10 8h27l-7 16H3z" />
      break
  }
  return (
    <svg width="40" height="32" viewBox="0 0 40 32" fill={fill} stroke={color} strokeWidth="1.6" strokeLinejoin="round" aria-hidden="true">
      {shape}
    </svg>
  )
}
