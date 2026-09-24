import { span, type Line, type SpanStyle } from './output'

const WIDTH = 72
const HEIGHT = 15
export const FRAME_COUNT = 16
export const FRAME_MS = 140

interface Burst {
  x: number
  y: number
  start: number
  style: SpanStyle
}

const BURSTS: Burst[] = [
  { x: 16, y: 5, start: 3, style: 'flag' },
  { x: 52, y: 4, start: 5, style: 'accent' },
  { x: 34, y: 7, start: 7, style: 'success' },
  { x: 62, y: 8, start: 9, style: 'match' },
  { x: 8, y: 9, start: 10, style: 'dir' },
]

const RING_CHARS = ['*', '*', '+', '+', '.', '.', ' ']

/** Deterministic ASCII fireworks: frame `f` of FRAME_COUNT, drawn onto a WIDTH x HEIGHT grid. */
export function fireworksFrame(f: number): Line[] {
  const chars: string[][] = Array.from({ length: HEIGHT }, () => Array<string>(WIDTH).fill(' '))
  const styles: (SpanStyle | undefined)[][] = Array.from({ length: HEIGHT }, () => Array<SpanStyle | undefined>(WIDTH).fill(undefined))

  const put = (x: number, y: number, ch: string, style: SpanStyle) => {
    const xi = Math.round(x)
    const yi = Math.round(y)
    if (xi < 0 || xi >= WIDTH || yi < 0 || yi >= HEIGHT) return
    chars[yi][xi] = ch
    styles[yi][xi] = style
  }

  for (const b of BURSTS) {
    const age = f - b.start
    if (age < 0) {
      // rocket climbing from the bottom toward the burst point
      const row = HEIGHT - 1 + (age + 1) * Math.ceil((HEIGHT - 1 - b.y) / 3)
      if (row > b.y) {
        put(b.x, row, '|', 'muted')
        put(b.x, row + 1, '.', 'muted')
      }
      continue
    }
    if (age === 0) {
      put(b.x, b.y, '*', b.style)
      continue
    }
    const ch = RING_CHARS[Math.min(age - 1, RING_CHARS.length - 1)]
    if (ch === ' ') continue
    const radius = age
    const points = 8 + age * 4
    for (let i = 0; i < points; i++) {
      const angle = (i / points) * Math.PI * 2
      put(b.x + Math.cos(angle) * radius * 2, b.y + Math.sin(angle) * radius, ch, b.style)
    }
    if (age >= 2) {
      // slower inner ring so the burst looks layered
      const inner = radius - 1.5
      for (let i = 0; i < 8; i++) {
        const angle = (i / 8) * Math.PI * 2 + 0.3
        put(b.x + Math.cos(angle) * inner * 2, b.y + Math.sin(angle) * inner, age > 4 ? '.' : '+', b.style)
      }
    }
    if (age >= 3) put(b.x, b.y + (age - 2) * 0.6, '.', 'muted')
  }

  return chars.map((row, y) => {
    const line: Line = []
    let text = ''
    let style: SpanStyle | undefined
    for (let x = 0; x < WIDTH; x++) {
      const s = row[x] === ' ' ? undefined : styles[y][x]
      if (s !== style && text) {
        line.push(span(text, style))
        text = ''
      }
      style = s
      text += row[x]
    }
    if (text) line.push(span(text, style))
    return line
  })
}
