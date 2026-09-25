export const PART_IDS = ['upper', 'overlays', 'stripe', 'laces', 'tongue', 'heel', 'sole', 'outsole'] as const
export type PartId = (typeof PART_IDS)[number]

export const PART_LABELS: Record<PartId, string> = {
  upper: 'Base',
  overlays: 'Overlays',
  stripe: 'Swoosh',
  laces: 'Laces',
  tongue: 'Tongue',
  heel: 'Heel tab',
  sole: 'Midsole',
  outsole: 'Outsole',
}

export const PART_HINTS: Record<PartId, string> = {
  upper: 'Quarter, vamp & collar',
  overlays: 'Toe cap, mudguard, eyestay & heel',
  stripe: 'Both sides',
  laces: 'Flat laces & tips',
  tongue: 'Padded tongue',
  heel: 'Engraved pull tab',
  sole: 'Cupsole wall',
  outsole: 'Rubber base',
}

export const FINISHES = ['matte', 'gloss', 'metallic', 'suede'] as const
export type Finish = (typeof FINISHES)[number]

export const FINISH_LABELS: Record<Finish, string> = {
  matte: 'Matte',
  gloss: 'Gloss',
  metallic: 'Metallic',
  suede: 'Suede',
}

export const LABEL_STYLES = ['embroidered', 'debossed', 'foil'] as const
export type LabelStyle = (typeof LABEL_STYLES)[number]

export const LABEL_STYLE_LABELS: Record<LabelStyle, string> = {
  embroidered: 'Embroidered',
  debossed: 'Debossed',
  foil: 'Gold foil',
}

/** Thread colours for the heel label. `auto` picks a contrasting ink from the tab colour. */
export const THREADS: { id: string; name: string; hex: string }[] = [
  { id: 'auto', name: 'Auto', hex: '' },
  { id: 'f6f3ec', name: 'Sail', hex: '#f6f3ec' },
  { id: '141414', name: 'Black', hex: '#141414' },
  { id: 'c9a44c', name: 'Metallic Gold', hex: '#c9a44c' },
  { id: 'c8102e', name: 'University Red', hex: '#c8102e' },
  { id: 'ceff00', name: 'Volt', hex: '#ceff00' },
  { id: '1f4bd8', name: 'Royal', hex: '#1f4bd8' },
]

export const VIEWS = ['hero', 'side', 'heel', 'top'] as const
export type ViewId = (typeof VIEWS)[number]

export const VIEW_LABELS: Record<ViewId, string> = {
  hero: 'Hero',
  side: 'Side',
  heel: 'Heel',
  top: 'Top',
}

export interface PartStyle {
  color: string
  finish: Finish
}

export interface SneakerConfig {
  parts: Record<PartId, PartStyle>
  text: string
  /** Thread id from THREADS. */
  ink: string
  label: LabelStyle
  view: ViewId
  spin: boolean
}

export const MAX_TEXT = 8

export const PALETTE: { hex: string; name: string }[] = [
  { hex: '#f4f4f2', name: 'White' },
  { hex: '#e8e2d2', name: 'Sail' },
  { hex: '#111111', name: 'Black' },
  { hex: '#8b8f96', name: 'Wolf Grey' },
  { hex: '#1c2841', name: 'Obsidian' },
  { hex: '#1f4bd8', name: 'Royal' },
  { hex: '#3cc4d4', name: 'Aqua' },
  { hex: '#1f6b4a', name: 'Gorge Green' },
  { hex: '#ceff00', name: 'Volt' },
  { hex: '#f2c230', name: 'Team Gold' },
  { hex: '#f26a1b', name: 'Orange' },
  { hex: '#c8102e', name: 'University Red' },
  { hex: '#f5b6cd', name: 'Pink Foam' },
  { hex: '#5b2a86', name: 'Court Purple' },
  { hex: '#6b4a2b', name: 'Baroque Brown' },
  { hex: '#c98d5a', name: 'Gum' },
]

export const DEFAULT_CONFIG: SneakerConfig = {
  parts: {
    upper: { color: '#f4f4f2', finish: 'matte' },
    overlays: { color: '#f4f4f2', finish: 'matte' },
    stripe: { color: '#111111', finish: 'gloss' },
    laces: { color: '#f4f4f2', finish: 'matte' },
    tongue: { color: '#f4f4f2', finish: 'matte' },
    heel: { color: '#111111', finish: 'matte' },
    sole: { color: '#f4f4f2', finish: 'matte' },
    outsole: { color: '#c98d5a', finish: 'matte' },
  },
  text: '',
  ink: 'auto',
  label: 'embroidered',
  view: 'hero',
  spin: false,
}

const HEX_RE = /^#?([0-9a-f]{6})$/i

export function normalizeHex(input: string): string | null {
  const m = HEX_RE.exec(input.trim())
  return m ? `#${m[1].toLowerCase()}` : null
}

export function sanitizeText(input: string): string {
  return input
    .toUpperCase()
    .replace(/[^A-Z0-9 .\-&!]/g, '')
    .slice(0, MAX_TEXT)
}

function isFinish(v: string): v is Finish {
  return (FINISHES as readonly string[]).includes(v)
}

function isView(v: string): v is ViewId {
  return (VIEWS as readonly string[]).includes(v)
}

/** Serialise a config to a URL hash such as `#upper=f4f4f2.matte&stripe=...&text=DEVIN&view=hero&spin=1`. */
export function encodeConfig(config: SneakerConfig): string {
  const params = new URLSearchParams()
  for (const id of PART_IDS) {
    const { color, finish } = config.parts[id]
    params.set(id, `${color.replace('#', '')}.${finish}`)
  }
  if (config.text) params.set('text', config.text)
  if (config.ink !== 'auto') params.set('ink', config.ink)
  if (config.label !== 'embroidered') params.set('label', config.label)
  params.set('view', config.view)
  if (config.spin) params.set('spin', '1')
  return `#${params.toString()}`
}

export function decodeConfig(hash: string): SneakerConfig | null {
  const raw = hash.startsWith('#') ? hash.slice(1) : hash
  if (!raw) return null
  const params = new URLSearchParams(raw)
  const config: SneakerConfig = structuredClone(DEFAULT_CONFIG)
  let touched = false
  for (const id of PART_IDS) {
    const value = params.get(id)
    if (!value) continue
    const [hexPart, finishPart = 'matte'] = value.split('.')
    const hex = normalizeHex(hexPart)
    if (!hex) continue
    config.parts[id] = { color: hex, finish: isFinish(finishPart) ? finishPart : 'matte' }
    touched = true
  }
  const text = params.get('text')
  if (text !== null) {
    config.text = sanitizeText(text)
    touched = true
  }
  const ink = params.get('ink')
  if (ink && THREADS.some((t) => t.id === ink)) {
    config.ink = ink
    touched = true
  }
  const label = params.get('label')
  if (label && (LABEL_STYLES as readonly string[]).includes(label)) {
    config.label = label as LabelStyle
    touched = true
  }
  const view = params.get('view')
  if (view && isView(view)) {
    config.view = view
    touched = true
  }
  if (params.get('spin') === '1') {
    config.spin = true
    touched = true
  }
  return touched ? config : null
}

/** Deterministic PRNG (mulberry32) so "Randomise #n" always yields the same design. */
export function mulberry32(seed: number): () => number {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export function randomConfig(seed: number, base: SneakerConfig): SneakerConfig {
  const rand = mulberry32(seed)
  const pick = <T,>(arr: readonly T[]): T => arr[Math.floor(rand() * arr.length)]
  // Curated colourways: a base, one or two accents and a neutral sole rather than eight dice rolls.
  const neutrals = PALETTE.slice(0, 5)
  const accents = PALETTE.slice(5)
  const finishFor = (): Finish => {
    const r = rand()
    return r < 0.6 ? 'matte' : r < 0.75 ? 'suede' : r < 0.9 ? 'gloss' : 'metallic'
  }
  const baseColor = pick(rand() < 0.5 ? neutrals : accents).hex
  const accent = pick(accents).hex
  const accent2 = pick(accents).hex
  const neutral = pick(neutrals).hex
  const soleColor = pick([...neutrals.slice(0, 3), PALETTE[PALETTE.length - 1]]).hex
  const parts: Record<PartId, PartStyle> = {
    upper: { color: baseColor, finish: finishFor() },
    overlays: { color: rand() < 0.5 ? baseColor : accent2, finish: finishFor() },
    stripe: { color: accent, finish: finishFor() },
    laces: { color: rand() < 0.6 ? neutral : accent, finish: 'matte' },
    tongue: { color: rand() < 0.6 ? baseColor : neutral, finish: 'matte' },
    heel: { color: rand() < 0.5 ? accent : neutral, finish: finishFor() },
    sole: { color: rand() < 0.75 ? soleColor : accent2, finish: 'matte' },
    outsole: { color: soleColor, finish: 'matte' },
  }
  return { ...base, parts }
}

export function relativeLuminance(hex: string): number {
  const n = parseInt(hex.replace('#', ''), 16)
  const chan = (c: number) => {
    const s = c / 255
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
  }
  return 0.2126 * chan((n >> 16) & 255) + 0.7152 * chan((n >> 8) & 255) + 0.0722 * chan(n & 255)
}

/** Resolved thread colour for the heel label. */
export function inkColor(ink: string, tabColor: string): string {
  const thread = THREADS.find((t) => t.id === ink)
  if (thread && thread.hex) return thread.hex
  return relativeLuminance(tabColor) > 0.35 ? '#141414' : '#f6f3ec'
}

type Parts = Record<PartId, PartStyle>
const m = (color: string, finish: Finish = 'matte'): PartStyle => ({ color, finish })

/** Curated one-click colourways. */
export const LOOKS: { id: string; name: string; parts: Parts }[] = [
  {
    id: 'triple-white',
    name: 'Triple White',
    parts: {
      upper: m('#f4f4f2'),
      overlays: m('#f4f4f2'),
      stripe: m('#f4f4f2'),
      laces: m('#f4f4f2'),
      tongue: m('#f4f4f2'),
      heel: m('#f4f4f2'),
      sole: m('#f4f4f2'),
      outsole: m('#f4f4f2'),
    },
  },
  {
    id: 'bred',
    name: 'Bred',
    parts: {
      upper: m('#111111'),
      overlays: m('#c8102e'),
      stripe: m('#111111', 'gloss'),
      laces: m('#111111'),
      tongue: m('#111111'),
      heel: m('#c8102e'),
      sole: m('#f4f4f2'),
      outsole: m('#111111'),
    },
  },
  {
    id: 'royal',
    name: 'Game Royal',
    parts: {
      upper: m('#f4f4f2'),
      overlays: m('#1f4bd8'),
      stripe: m('#1f4bd8', 'gloss'),
      laces: m('#f4f4f2'),
      tongue: m('#f4f4f2'),
      heel: m('#1f4bd8'),
      sole: m('#f4f4f2'),
      outsole: m('#1c2841'),
    },
  },
  {
    id: 'gum-suede',
    name: 'Wheat Gum',
    parts: {
      upper: m('#c98d5a', 'suede'),
      overlays: m('#6b4a2b', 'suede'),
      stripe: m('#e8e2d2'),
      laces: m('#6b4a2b'),
      tongue: m('#c98d5a', 'suede'),
      heel: m('#6b4a2b'),
      sole: m('#e8e2d2'),
      outsole: m('#c98d5a'),
    },
  },
  {
    id: 'volt',
    name: 'Volt Night',
    parts: {
      upper: m('#1c2841'),
      overlays: m('#111111'),
      stripe: m('#ceff00', 'gloss'),
      laces: m('#ceff00'),
      tongue: m('#1c2841'),
      heel: m('#ceff00'),
      sole: m('#111111'),
      outsole: m('#111111'),
    },
  },
  {
    id: 'chrome',
    name: 'Liquid Chrome',
    parts: {
      upper: m('#8b8f96', 'metallic'),
      overlays: m('#f4f4f2'),
      stripe: m('#111111', 'gloss'),
      laces: m('#f4f4f2'),
      tongue: m('#f4f4f2'),
      heel: m('#111111'),
      sole: m('#f4f4f2'),
      outsole: m('#8b8f96'),
    },
  },
]
