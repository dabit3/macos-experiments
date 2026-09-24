import * as THREE from 'three'
import { mulberry32, type LabelStyle } from '../config'

// Aspect matches the heel label patch.
export const LABEL_W = 1024
export const LABEL_H = 560

const FONT = '"Futura", "Helvetica Neue", Helvetica, Arial, "Liberation Sans", system-ui, sans-serif'
const MARK =
  'M2.5 16.5c5.5-1.2 12.4-4 19-8.3-1.6 3.3-3.4 5.6-5.6 7.2-3.9 2.9-9.1 3.4-13.4 1.1z'

export interface LabelArt {
  /** Transparent colour layer: thread / foil / pressed-in shading. */
  color: HTMLCanvasElement
  /** Height field for the label leather (0.5 = flat). */
  height: HTMLCanvasElement
}

function canvas(): [HTMLCanvasElement, CanvasRenderingContext2D] {
  const c = document.createElement('canvas')
  c.width = LABEL_W
  c.height = LABEL_H
  const ctx = c.getContext('2d')
  if (!ctx) throw new Error('2D canvas unavailable')
  return [c, ctx]
}

/** Draws the label content (text or mark) as a solid silhouette with the current fill style. */
function drawGlyphs(ctx: CanvasRenderingContext2D, text: string, size: number): void {
  if (!text) {
    const scale = 21
    ctx.save()
    ctx.translate(LABEL_W / 2 - 12 * scale, LABEL_H / 2 - 12.5 * scale)
    ctx.scale(scale, scale)
    ctx.fill(new Path2D(MARK))
    ctx.restore()
    return
  }
  ctx.font = `700 ${size}px ${FONT}`
  ctx.letterSpacing = `${Math.round(size * 0.06)}px`
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillText(text, LABEL_W / 2, LABEL_H / 2 + size * 0.04)
}

function fitSize(text: string): number {
  if (!text) return 0
  const [, ctx] = canvas()
  let size = 230
  const fits = () => {
    ctx.font = `700 ${size}px ${FONT}`
    ctx.letterSpacing = `${Math.round(size * 0.06)}px`
    return ctx.measureText(text).width < LABEL_W - 220
  }
  while (!fits() && size > 70) size -= 4
  return size
}

/** A glyph mask as its own canvas so it can be composited, blurred or offset. */
function mask(text: string, size: number, fill = '#fff'): HTMLCanvasElement {
  const [c, ctx] = canvas()
  ctx.fillStyle = fill
  drawGlyphs(ctx, text, size)
  return c
}

/** Satin stitch: fine parallel thread lines clipped to the glyphs. */
function satin(ctx: CanvasRenderingContext2D, light: string, dark: string, step: number): void {
  ctx.save()
  ctx.globalCompositeOperation = 'source-atop'
  ctx.lineWidth = step * 0.45
  for (let k = -LABEL_H; k < LABEL_W + LABEL_H; k += step) {
    ctx.strokeStyle = light
    ctx.beginPath()
    ctx.moveTo(k, 0)
    ctx.lineTo(k + LABEL_H * 0.35, LABEL_H)
    ctx.stroke()
    ctx.strokeStyle = dark
    ctx.beginPath()
    ctx.moveTo(k + step / 2, 0)
    ctx.lineTo(k + step / 2 + LABEL_H * 0.35, LABEL_H)
    ctx.stroke()
  }
  ctx.restore()
}

const INSET = 46

function stitchPath(ctx: CanvasRenderingContext2D): void {
  ctx.beginPath()
  ctx.rect(INSET, INSET, LABEL_W - 2 * INSET, LABEL_H - 2 * INSET)
}

/**
 * Renders the heel label. Stitches and lettering are drawn straight; the label patch itself
 * has rounded corners, so the border follows them once mapped.
 */
export function drawLabel(text: string, ink: string, style: LabelStyle): LabelArt {
  const size = fitSize(text)
  const [color, cc] = canvas()
  const [height, hc] = canvas()

  // Height field: fine leather grain around a flat 0.5 base.
  const image = hc.createImageData(LABEL_W, LABEL_H)
  const rand = mulberry32(7)
  for (let i = 0; i < image.data.length; i += 4) {
    const v = 128 + (rand() - 0.5) * 18
    image.data[i] = image.data[i + 1] = image.data[i + 2] = v
    image.data[i + 3] = 255
  }
  hc.putImageData(image, 0, 0)

  // Edge channel: a pressed groove the stitches sit in.
  hc.save()
  hc.strokeStyle = 'rgba(40,40,40,0.9)'
  hc.lineWidth = 16
  hc.filter = 'blur(4px)'
  stitchPath(hc)
  hc.stroke()
  hc.restore()

  // Running stitch, tonal to the thread.
  const stitch = (ctx: CanvasRenderingContext2D, stroke: string, width: number) => {
    ctx.save()
    ctx.strokeStyle = stroke
    ctx.lineWidth = width
    ctx.lineCap = 'round'
    ctx.setLineDash([22, 16])
    stitchPath(ctx)
    ctx.stroke()
    ctx.restore()
  }
  stitch(hc, '#ffffff', 9)
  stitch(cc, style === 'foil' ? 'rgba(20,20,20,0.35)' : ink, 7)

  const glyphs = mask(text, size)
  if (style === 'embroidered') {
    // Raised thread with a soft shoulder.
    hc.save()
    hc.filter = 'blur(6px)'
    hc.globalAlpha = 0.9
    hc.drawImage(glyphs, 0, 0)
    hc.restore()
    const ridges = mask(text, size, '#e6e6e6')
    satin(ridges.getContext('2d')!, 'rgba(255,255,255,1)', 'rgba(170,170,170,1)', 10)
    hc.drawImage(ridges, 0, 0)

    cc.save()
    cc.filter = 'blur(3px)'
    cc.globalAlpha = 0.45
    cc.drawImage(mask(text, size, '#000'), 2, 5)
    cc.restore()
    const thread = mask(text, size, ink)
    satin(thread.getContext('2d')!, 'rgba(255,255,255,0.16)', 'rgba(0,0,0,0.14)', 10)
    cc.drawImage(thread, 0, 0)
  } else if (style === 'debossed') {
    // Pressed into the leather: low, darker, with a lit lower lip.
    hc.save()
    hc.filter = 'blur(3px)'
    hc.drawImage(mask(text, size, '#141414'), 0, 0)
    hc.restore()
    cc.save()
    cc.globalAlpha = 0.34
    cc.drawImage(mask(text, size, '#000'), 0, 0)
    cc.globalAlpha = 0.22
    cc.filter = 'blur(2px)'
    cc.drawImage(mask(text, size, '#000'), 0, -4)
    cc.globalAlpha = 0.16
    cc.drawImage(mask(text, size, '#fff'), 0, 5)
    cc.restore()
  } else {
    // Hot-stamped foil: slightly pressed in, with a polished metallic gradient.
    hc.save()
    hc.filter = 'blur(2px)'
    hc.drawImage(mask(text, size, '#3c3c3c'), 0, 0)
    hc.restore()
    const foil = mask(text, size)
    const fc = foil.getContext('2d')!
    fc.globalCompositeOperation = 'source-atop'
    const g = fc.createLinearGradient(0, LABEL_H * 0.2, 0, LABEL_H * 0.8)
    g.addColorStop(0, '#fff1c1')
    g.addColorStop(0.35, '#d9b45a')
    g.addColorStop(0.6, '#a07a2c')
    g.addColorStop(1, '#e8c874')
    fc.fillStyle = g
    fc.fillRect(0, 0, LABEL_W, LABEL_H)
    cc.drawImage(foil, 0, 0)
  }
  return { color, height }
}

export function makeLabelTextures(
  text: string,
  ink: string,
  style: LabelStyle,
): { map: THREE.CanvasTexture; bump: THREE.CanvasTexture } {
  const art = drawLabel(text, ink, style)
  const map = new THREE.CanvasTexture(art.color)
  map.colorSpace = THREE.SRGBColorSpace
  map.anisotropy = 8
  const bump = new THREE.CanvasTexture(art.height)
  bump.anisotropy = 8
  return { map, bump }
}
