import * as THREE from 'three'
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js'
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js'
import { PART_IDS, mulberry32, type PartId } from '../config'

/**
 * A low-top court sneaker (Air Force 1 silhouette) modelled procedurally from a lofted
 * "last" surface. Every overlay panel — toe cap, mudguard, eyestay, heel counter and the
 * swoosh — is a thin shell offset from that same surface, so the panels always sit flush
 * on the upper no matter how the profile curves are tuned.
 */
export interface SneakerModel {
  root: THREE.Group
  /** Every mesh that belongs to a configurable part, grouped by part. */
  partMeshes: Record<PartId, THREE.Mesh[]>
  /** One shared material per part. */
  materials: Record<PartId, THREE.MeshPhysicalMaterial>
  /** The decal skin on the heel label that carries the engraving texture. */
  engravingMaterial: THREE.MeshStandardMaterial
}

// ---------------------------------------------------------------------------
// 1D profile curves (monotone cubic Hermite through x-sorted control points)
// ---------------------------------------------------------------------------

type Curve1D = (x: number) => number

function profile(points: [number, number][]): Curve1D {
  const xs = points.map((p) => p[0])
  const ys = points.map((p) => p[1])
  const n = points.length
  const h = xs.slice(1).map((x, i) => x - xs[i])
  const d = ys.slice(1).map((y, i) => (y - ys[i]) / h[i])
  // Fritsch–Carlson tangents: no overshoot between control points.
  const m = ys.map((_, i) => {
    if (i === 0) return d[0]
    if (i === n - 1) return d[n - 2]
    if (d[i - 1] * d[i] <= 0) return 0
    const w1 = 2 * h[i] + h[i - 1]
    const w2 = h[i] + 2 * h[i - 1]
    return (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
  })
  return (x) => {
    if (x <= xs[0]) return ys[0]
    if (x >= xs[n - 1]) return ys[n - 1]
    let i = 0
    while (x > xs[i + 1]) i++
    const t = (x - xs[i]) / h[i]
    const t2 = t * t
    const t3 = t2 * t
    return (
      (2 * t3 - 3 * t2 + 1) * ys[i] +
      (t3 - 2 * t2 + t) * h[i] * m[i] +
      (-2 * t3 + 3 * t2) * ys[i + 1] +
      (t3 - t2) * h[i] * m[i + 1]
    )
  }
}

/** Smoothstep that also accepts reversed edges (a > b). */
function sstep(a: number, b: number, x: number): number {
  const t = THREE.MathUtils.clamp((x - a) / (b - a), 0, 1)
  return t * t * (3 - 2 * t)
}

// ---------------------------------------------------------------------------
// The last: a superelliptic tube swept along x
// ---------------------------------------------------------------------------

const X0 = -1.3
const X1 = 1.45
const BASE_Y = 0.27
/** How far the upper is tucked below its base line into the midsole. */
const DIP = 0.08

/** Height of the upper above its base line: tall padded collar, sloping down the throat. */
const HEIGHT = profile([
  [-1.3, 0.7],
  [-1.27, 0.74],
  [-1.2, 0.76],
  [-1.1, 0.77],
  [-0.95, 0.78],
  [-0.7, 0.78],
  [-0.5, 0.75],
  [-0.3, 0.7],
  [0.0, 0.61],
  [0.3, 0.53],
  [0.6, 0.44],
  [0.9, 0.345],
  [1.15, 0.26],
  [1.3, 0.2],
  [1.4, 0.13],
  [1.44, 0.07],
  [1.45, 0.03],
])

/** Half-width of the upper: a round heel cup, widest over the ball of the foot. */
const WIDTH = profile([
  [-1.3, 0.0],
  [-1.295, 0.1],
  [-1.28, 0.17],
  [-1.25, 0.24],
  [-1.2, 0.3],
  [-1.1, 0.36],
  [-0.95, 0.4],
  [-0.7, 0.43],
  [-0.3, 0.45],
  [0.2, 0.49],
  [0.6, 0.53],
  [0.95, 0.5],
  [1.2, 0.42],
  [1.32, 0.34],
  [1.4, 0.24],
  [1.44, 0.13],
  [1.45, 0.03],
])

/** Superellipse exponent: boxy (flat deck, vertical walls) through the ankle, round at both ends. */
const BOXINESS = profile([
  [-1.3, 2.2],
  [-1.15, 2.8],
  [-0.9, 3.2],
  [-0.5, 3.1],
  [0.0, 2.9],
  [0.6, 2.6],
  [1.1, 2.2],
  [1.45, 2.0],
])

/** Toe spring + a touch of heel lift, applied to the upper and to the sole. */
function lift(x: number): number {
  const toe = Math.max(0, x - 0.55) / 0.9
  const heel = Math.max(0, -x - 1.0) / 0.3
  return 0.24 * toe * toe + 0.06 * heel * heel
}

function baseY(x: number): number {
  return BASE_Y + lift(x)
}

/** Cosine spacing along x clusters rows at the heel and toe where the last curves fastest. */
const xAt = (u: number): number => X0 + ((X1 - X0) * (1 - Math.cos(Math.PI * u))) / 2
const uAt = (x: number): number => Math.acos(1 - 2 * THREE.MathUtils.clamp((x - X0) / (X1 - X0), 0, 1)) / Math.PI

// Foot opening carved into the deck at the ankle, and the throat channel the tongue lies in.
const OPEN_X = -0.8
const OPEN_RX = 0.34
const OPEN_RZ = 0.6
const OPEN_DEPTH = 0.15
const THROAT_X0 = -0.62
const THROAT_X1 = 0.75
const THROAT_DEPTH = 0.06

/** Depth to sink the deck at (x, z / width); `ss` is the height fraction so walls are untouched. */
function carve(x: number, zf: number, ss: number): number {
  const r = Math.hypot((x - OPEN_X) / OPEN_RX, zf / OPEN_RZ)
  const bowl = OPEN_DEPTH * sstep(1, 0.45, r)
  const along = sstep(THROAT_X0 - 0.15, THROAT_X0 + 0.1, x) * (1 - sstep(THROAT_X1 - 0.35, THROAT_X1, x))
  const across = 1 - sstep(0.28, 0.46, Math.abs(zf))
  return Math.max(bowl, THROAT_DEPTH * along * across) * ss * ss * ss
}

/** θ ∈ [0, π] runs from +z over the top to −z. */
function surface(u: number, theta: number, out: THREE.Vector3): THREE.Vector3 {
  const x = xAt(u)
  const p = 2 / BOXINESS(x)
  const c = Math.cos(theta)
  const s = Math.sin(theta)
  const cc = Math.sign(c) * Math.abs(c) ** p
  const ss = Math.abs(s) ** p
  const y = baseY(x) - DIP + (HEIGHT(x) + DIP) * ss - carve(x, cc, ss)
  return out.set(x, y, WIDTH(x) * cc)
}

const _a = new THREE.Vector3()
const _b = new THREE.Vector3()
const _c = new THREE.Vector3()
const _d = new THREE.Vector3()
const _e = new THREE.Vector3()

function normalAt(u: number, theta: number, out: THREE.Vector3): THREE.Vector3 {
  const eu = 0.002
  const et = 0.004
  surface(Math.min(1, u + eu), theta, _a)
  surface(Math.max(0, u - eu), theta, _b)
  surface(u, Math.min(Math.PI, theta + et), _c)
  surface(u, Math.max(0, theta - et), _d)
  _a.sub(_b)
  _c.sub(_d)
  out.crossVectors(_a, _c)
  if (out.lengthSq() < 1e-10) return out.set(u > 0.5 ? 1 : -1, 0, 0)
  out.normalize()
  // The last pinches to a line at both ends; ease the normal onto the axis there so
  // panels meeting at the seam are offset the same way from either side.
  const axial = sstep(0.03, 0, u) + sstep(0.97, 1, u)
  if (axial > 0) out.lerp(_e.set(u > 0.5 ? 1 : -1, 0, 0), axial).normalize()
  return out
}

/**
 * θ for a given height fraction of the cross-section (0 = base line, 1 = top ridge).
 * `side` +1 is the +z (lateral) side, −1 the −z side.
 */
function thetaAtHeight(u: number, frac: number, side: 1 | -1): number {
  const p = BOXINESS(xAt(u))
  const f = THREE.MathUtils.clamp(frac, 0, 1)
  const t = Math.asin(f ** (p / 2))
  return side === 1 ? t : Math.PI - t
}

// ---------------------------------------------------------------------------
// Mesh builders
// ---------------------------------------------------------------------------

type PointFn = (i: number, j: number, out: THREE.Vector3) => THREE.Vector3

interface GridBuild {
  positions: number[]
  uvs: number[]
  index: number[]
}

function newBuild(): GridBuild {
  return { positions: [], uvs: [], index: [] }
}

function quad(index: number[], a: number, b: number, c: number, d: number): void {
  index.push(a, b, d, a, d, c)
}

/** A single-sided (i × j) grid; triangles wind so that di × dj is the front normal. */
function skin(build: GridBuild, n: number, m: number, at: PointFn, flip = false): number {
  const base = build.positions.length / 3
  const v = new THREE.Vector3()
  for (let i = 0; i <= n; i++) {
    for (let j = 0; j <= m; j++) {
      at(i, j, v)
      build.positions.push(v.x, v.y, v.z)
      build.uvs.push(i / n, j / m)
    }
  }
  const id = (i: number, j: number): number => base + i * (m + 1) + j
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < m; j++) {
      if (flip) quad(build.index, id(i, j), id(i, j + 1), id(i + 1, j), id(i + 1, j + 1))
      else quad(build.index, id(i, j), id(i + 1, j), id(i, j + 1), id(i + 1, j + 1))
    }
  }
  return base
}

function flipWinding(index: number[]): void {
  for (let k = 0; k < index.length; k += 3) {
    const tmp = index[k + 1]
    index[k + 1] = index[k + 2]
    index[k + 2] = tmp
  }
}

function finishGeometry(build: GridBuild): THREE.BufferGeometry {
  const geom = new THREE.BufferGeometry()
  geom.setAttribute('position', new THREE.Float32BufferAttribute(build.positions, 3))
  if (build.uvs.length * 3 === build.positions.length * 2) {
    geom.setAttribute('uv', new THREE.Float32BufferAttribute(build.uvs, 2))
  }
  geom.setIndex(build.index)
  geom.computeVertexNormals()
  return geom
}

/** Surface on the last over the full (u, θ) domain, capped at the heel and toe ends. */
function lastSurface(n: number, m: number): THREE.BufferGeometry {
  const build = newBuild()
  skin(build, n, m, (i, j, out) => surface(i / n, (j / m) * Math.PI, out))
  const v = new THREE.Vector3()
  for (const [u, flip] of [
    [0, false],
    [1, true],
  ] as const) {
    const ring = build.positions.length / 3
    for (let j = 0; j <= m; j++) {
      surface(u, (j / m) * Math.PI, v)
      build.positions.push(v.x, v.y, v.z)
      build.uvs.push(u, j / m)
    }
    const centre = build.positions.length / 3
    surface(u, 0, v)
    build.positions.push(v.x, baseY(xAt(u)) - DIP, 0)
    build.uvs.push(u, 0.5)
    for (let j = 0; j < m; j++) {
      if (flip) build.index.push(centre, ring + j + 1, ring + j)
      else build.index.push(centre, ring + j, ring + j + 1)
    }
  }
  return finishGeometry(build)
}

interface PatchSpec {
  /** Maps patch coordinates (s, t) ∈ [0,1]² to a (u, θ) position on the last. */
  domain: (s: number, t: number) => [number, number]
  n: number
  m: number
  /** Outward offset of the visible face at the centre of the panel. */
  raise: number
  /** Uniform outward offset added everywhere (lets a panel sit on top of another panel). */
  base?: number
  /** How deep the shell sinks below the surface (hides the seam). */
  sink?: number
  /**
   * Width, in (s, t) units, of the rounded roll-off along each edge so the panel reads as
   * padded leather rather than a plate. Order: [s = 0, s = 1, t = 0, t = 1]; 0 = square edge.
   */
  bevel?: [number, number, number, number]
}

/** Quarter-circle roll-off: 1 in the middle of the panel, 0 at a bevelled edge. */
function crown(s: number, t: number, bevel: [number, number, number, number]): number {
  const roll = (d: number, w: number): number => (w <= 0 ? 1 : Math.sqrt(1 - (1 - Math.min(1, d / w)) ** 2))
  return roll(s, bevel[0]) * roll(1 - s, bevel[1]) * roll(t, bevel[2]) * roll(1 - t, bevel[3])
}

/** Front-skin offset of a patch at (s, t). */
function patchOffset(spec: PatchSpec, s: number, t: number): number {
  const bevel = spec.bevel ?? [0.12, 0.12, 0.12, 0.12]
  // A small floor keeps bevelled edges clear of the upper so the outline is the panel's own
  // (smooth) mesh edge rather than a jagged intersection of two tessellated surfaces.
  return (spec.base ?? 0.004) + spec.raise * crown(s, t, bevel)
}

/**
 * Mirrored domains (θ decreasing with t) turn a shell inside out; flip the winding so the
 * front skin always faces along the surface normal.
 */
function fixWinding(build: GridBuild, { domain, n, m }: PatchSpec): void {
  const nrm = new THREE.Vector3()
  const [u0, t0] = domain(0.5, 0.5)
  const [u1, t1] = domain(0.5 + 0.5 / n, 0.5)
  const [u2, t2] = domain(0.5, 0.5 + 0.5 / m)
  normalAt(u0, t0, nrm)
  surface(u0, t0, _a)
  surface(u1, t1, _b).sub(_a)
  surface(u2, t2, _c).sub(_a)
  if (_b.cross(_c).dot(nrm) < 0) flipWinding(build.index)
}

/** Only the visible skin of a patch (with UVs), lifted `extra` above it — used for decals. */
function patchSkin(spec: PatchSpec, extra: number): THREE.BufferGeometry {
  const build = newBuild()
  const nrm = new THREE.Vector3()
  const { n, m, domain } = spec
  skin(build, n, m, (i, j, out) => {
    const s = i / n
    const t = j / m
    const [u, theta] = domain(s, t)
    surface(u, theta, out)
    normalAt(u, theta, nrm)
    return out.addScaledVector(nrm, patchOffset(spec, s, t) + extra)
  })
  fixWinding(build, spec)
  return finishGeometry(build)
}

/** A closed shell that hugs the last: crowned front skin, sunken back skin and four edge walls. */
function patch(spec: PatchSpec): THREE.BufferGeometry {
  const { domain, n, m, sink = 0.02 } = spec
  const build = newBuild()
  const nrm = new THREE.Vector3()
  const pointAt =
    (offset: (s: number, t: number) => number): PointFn =>
    (i, j, out) => {
      const s = i / n
      const t = j / m
      const [u, theta] = domain(s, t)
      surface(u, theta, out)
      normalAt(u, theta, nrm)
      return out.addScaledVector(nrm, offset(s, t))
    }
  const front = skin(
    build,
    n,
    m,
    pointAt((s, t) => patchOffset(spec, s, t)),
  )
  const back = skin(
    build,
    n,
    m,
    pointAt(() => -sink),
    true,
  )
  const f = (i: number, j: number): number => front + i * (m + 1) + j
  const b = (i: number, j: number): number => back + i * (m + 1) + j
  for (let i = 0; i < n; i++) {
    quad(build.index, f(i, 0), b(i, 0), f(i + 1, 0), b(i + 1, 0))
    quad(build.index, f(i, m), f(i + 1, m), b(i, m), b(i + 1, m))
  }
  for (let j = 0; j < m; j++) {
    quad(build.index, f(0, j), f(0, j + 1), b(0, j), b(0, j + 1))
    quad(build.index, f(n, j), b(n, j), f(n, j + 1), b(n, j + 1))
  }
  fixWinding(build, spec)
  return finishGeometry(build)
}

/** A flat lace: a rectangular section swept along `curve`, kept level with `up`. */
function ribbon(
  curve: THREE.Curve<THREE.Vector3>,
  up: THREE.Vector3,
  width: number,
  thick: number,
): THREE.BufferGeometry {
  const build = newBuild()
  const p = new THREE.Vector3()
  const tan = new THREE.Vector3()
  const side = new THREE.Vector3()
  const nrm = new THREE.Vector3()
  const corners: [number, number][] = [
    [1, 1],
    [-1, 1],
    [-1, -1],
    [1, -1],
  ]
  const segments = 18
  skin(build, segments, 4, (i, j, out) => {
    const s = i / segments
    curve.getPoint(s, p)
    curve.getTangent(s, tan)
    side.crossVectors(tan, up).normalize()
    nrm.crossVectors(side, tan).normalize()
    const [a, b] = corners[j % 4]
    return out
      .copy(p)
      .addScaledVector(side, (a * width) / 2)
      .addScaledVector(nrm, (b * thick) / 2)
  })
  return finishGeometry(build)
}

/**
 * Half-width of the sole footprint at x: the last's width plus a lip, with the heel and toe
 * finished as broad elliptical ends (the raw last pinches to a point at both ends).
 */
function footprint(x: number, margin: number): number {
  const heelR = 0.34
  const toeR = 0.26
  const xh = X0 - margin + heelR
  const xt = X1 + margin - toeR
  const wh = WIDTH(xh) + margin
  const wt = WIDTH(xt) + margin
  if (x < xh) return wh * Math.sqrt(Math.max(0, 1 - ((xh - x) / heelR) ** 2))
  if (x > xt) return wt * Math.sqrt(Math.max(0, 1 - ((x - xt) / toeR) ** 2))
  // Ease the straight-ish sides into the flat-tangent ends so the outline has no kinks.
  const w = WIDTH(x) + margin
  return THREE.MathUtils.lerp(THREE.MathUtils.lerp(w, wh, sstep(xh + 0.16, xh, x)), wt, sstep(xt - 0.16, xt, x))
}

/** Closed footprint outline as (x, z) points, heel → toe → heel. */
export function footprintOutline(margin: number, n = 120): THREE.Vector2[] {
  const out: THREE.Vector2[] = []
  const xmin = X0 - margin
  const xmax = X1 + margin
  for (let i = 0; i <= n; i++) {
    const x = xmin + ((xmax - xmin) * (1 - Math.cos(Math.PI * (i / n)))) / 2
    out.push(new THREE.Vector2(x, footprint(x, margin)))
  }
  for (let i = n - 1; i > 0; i--) out.push(new THREE.Vector2(out[i].x, -out[i].y))
  return out
}

/** "AIR" moulded into the midsole wall. */
function airTexture(): THREE.CanvasTexture {
  const c = document.createElement('canvas')
  c.width = 512
  c.height = 128
  const ctx = c.getContext('2d')!
  ctx.font = 'italic 800 104px "Futura", "Helvetica Neue", Arial, "Liberation Sans", sans-serif'
  ctx.letterSpacing = '6px'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillStyle = 'rgba(255,255,255,0.55)'
  ctx.fillText('AIR', 258, 70)
  ctx.fillStyle = 'rgba(0,0,0,0.2)'
  ctx.fillText('AIR', 256, 66)
  const tex = new THREE.CanvasTexture(c)
  tex.colorSpace = THREE.SRGBColorSpace
  tex.anisotropy = 8
  return tex
}

interface SoleSpec {
  margin: number
  /** Bottom of the shell (before toe spring). */
  y0: number
  height: number
  /** Radius of the rounded bottom and top edges. */
  rBottom: number
  rTop: number
  /** How far the wall leans inward from bottom to top. */
  taper?: number
  /** Extra bulge of the wall at mid-height (a moulded cupsole belly). */
  belly?: number
}

/**
 * A sole shell swept around the footprint: rounded bottom edge, (optionally bellied) wall,
 * rounded top edge and flat caps, all following the toe spring. Unlike an extrusion the
 * surface is one smooth grid, so highlights sweep around it without polygonal steps.
 */
function soleShell({ margin, y0, height, rBottom, rTop, taper = 0, belly = 0 }: SoleSpec): THREE.BufferGeometry {
  const N = 120 // points along one side of the footprint
  const Q = 5 // segments per rounded edge
  const outline: THREE.Vector2[] = []
  const xmin = X0 - margin
  const xmax = X1 + margin
  for (let i = 0; i <= N; i++) {
    const x = xmin + ((xmax - xmin) * (1 - Math.cos(Math.PI * (i / N)))) / 2
    outline.push(new THREE.Vector2(x, footprint(x, margin)))
  }
  for (let i = N - 1; i > 0; i--) outline.push(new THREE.Vector2(outline[i].x, -outline[i].y))
  const L = outline.length
  const normals = outline.map((p, i) => {
    const prev = outline[(i - 1 + L) % L]
    const next = outline[(i + 1) % L]
    const n = new THREE.Vector2(next.y - prev.y, -(next.x - prev.x)).normalize()
    return n.dot(p) < 0 ? n.negate() : n
  })

  // Wall profile from the bottom edge to the top edge as (inset, height) pairs.
  const prof: [number, number][] = []
  for (let q = 0; q <= Q; q++) {
    const a = (q / Q) * (Math.PI / 2)
    prof.push([rBottom * (1 - Math.sin(a)), rBottom * (1 - Math.cos(a))])
  }
  const wallSegs = 6
  for (let k = 1; k < wallSegs; k++) {
    const f = k / wallSegs
    const y = THREE.MathUtils.lerp(rBottom, height - rTop, f)
    prof.push([taper * f - belly * Math.sin(Math.PI * f), y])
  }
  for (let q = 0; q <= Q; q++) {
    const a = (q / Q) * (Math.PI / 2)
    prof.push([taper + rTop * (1 - Math.cos(a)), height - rTop + rTop * Math.sin(a)])
  }

  const build = newBuild()
  const P = prof.length - 1
  skin(build, L, P, (i, j, out) => {
    const k = i % L
    const [inset, y] = prof[j]
    const p = outline[k]
    const n = normals[k]
    const x = p.x - n.x * inset
    return out.set(x, y0 + y + lift(THREE.MathUtils.clamp(x, X0, X1)), p.y - n.y * inset)
  })
  // Caps: ruled strips between the +z and −z sides so they follow the toe spring.
  const capInset = prof[P][0]
  const cap = (y: number, inset: number, flip: boolean) =>
    skin(
      build,
      N,
      8,
      (i, j, out) => {
        const p = outline[i]
        const n = normals[i]
        const x = p.x - n.x * inset
        const z = (p.y - n.y * inset) * (1 - (2 * j) / 8)
        return out.set(x, y0 + y + lift(THREE.MathUtils.clamp(x, X0, X1)), z)
      },
      flip,
    )
  cap(height, capInset, false)
  cap(0, rBottom, true)

  const geom = finishGeometry(build)
  // Orient outward: a wall vertex halfway along the +z side must have a +z normal.
  const probe = Math.floor(N / 2) * (P + 1) + Math.floor(P / 2)
  if (geom.attributes.normal.getZ(probe) < 0) {
    flipWinding(build.index)
    return finishGeometry(build)
  }
  return geom
}

/** Places an object on the last at (u, θ), facing outward. */
function placeOnLast(obj: THREE.Object3D, u: number, theta: number, offset: number): void {
  const p = new THREE.Vector3()
  const nrm = new THREE.Vector3()
  surface(u, theta, p)
  normalAt(u, theta, nrm)
  obj.position.copy(p).addScaledVector(nrm, offset)
  obj.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), nrm)
}

// ---------------------------------------------------------------------------
// Panel layouts (in x × height-fraction space)
// ---------------------------------------------------------------------------

const TOE_CAP_X = 0.86
const EYELET_XS = [-0.36, -0.2, -0.04, 0.12, 0.28, 0.44, 0.6]
const EYELET_HEIGHT = 0.9

function toeCap(): THREE.BufferGeometry {
  return patch({
    n: 18,
    m: 48,
    raise: 0.024,
    bevel: [0.2, 0, 0, 0],
    domain: (s, t) => {
      const theta = t * Math.PI
      // Rear edge bows back over the top of the foot.
      const x0 = TOE_CAP_X - 0.08 * Math.sin(theta)
      return [uAt(THREE.MathUtils.lerp(x0, X1, s)), theta]
    },
  })
}

function mudguard(side: 1 | -1): THREE.BufferGeometry {
  const xA = -0.5
  // Runs on under the toe cap, which is stitched over it.
  const xB = TOE_CAP_X + 0.14
  return patch({
    n: 30,
    m: 10,
    raise: 0.018,
    bevel: [0.1, 0, 0, 0.28],
    domain: (s, t) => {
      // Rounded rear end: the corners are pulled forward, the middle of the edge stays.
      const rear = xA + 0.14 * (1 - Math.sin(Math.PI * t)) ** 2
      const x = THREE.MathUtils.lerp(rear, xB, s)
      const u = uAt(x)
      const top = 0.22 + 0.38 * s ** 1.4
      return [u, thetaAtHeight(u, THREE.MathUtils.lerp(-0.02, top, t), side)]
    },
  })
}

function eyestay(side: 1 | -1): THREE.BufferGeometry {
  const xA = -0.42
  const xB = TOE_CAP_X + 0.1
  return patch({
    n: 28,
    m: 10,
    raise: 0.02,
    bevel: [0.1, 0, 0.3, 0.3],
    domain: (s, t) => {
      const x = THREE.MathUtils.lerp(xA, xB, s)
      const u = uAt(x)
      const bottom = THREE.MathUtils.lerp(0.66, 0.6, s)
      return [u, thetaAtHeight(u, THREE.MathUtils.lerp(bottom, 0.94, t), side)]
    },
  })
}

/** One panel wrapping around the heel: s runs lateral front → back → medial front. */
function heelCounter(): THREE.BufferGeometry {
  return patch({
    n: 80,
    m: 20,
    raise: 0.018,
    sink: 0.006,
    bevel: [0.12, 0.12, 0, 0.16],
    domain: (s, t) => {
      const side: 1 | -1 = s < 0.5 ? 1 : -1
      const k = Math.abs(2 * s - 1)
      // Front edge sweeps back as it rises so the top-front corner is a soft curve.
      const x = THREE.MathUtils.lerp(X0, -0.7 - 0.2 * t * t, k)
      const u = uAt(x)
      // Top edge at an absolute height (tallest at the back) rather than a fraction of the profile.
      const top = Math.min(1, THREE.MathUtils.lerp(0.52, 0.3, k * k) / HEIGHT(x))
      return [u, thetaAtHeight(u, t * top, side)]
    },
  })
}

function swoosh(side: 1 | -1): THREE.BufferGeometry {
  // Centre line in (x, height-fraction): blunt nose low over the mudguard, sweeping back and up.
  const centre = new THREE.CubicBezierCurve(
    new THREE.Vector2(0.66, 0.37),
    new THREE.Vector2(0.4, 0.07),
    new THREE.Vector2(-0.4, 0.24),
    new THREE.Vector2(-1.04, 0.8),
  )
  const halfWidth = (s: number): number => {
    const cap = s < 0.12 ? Math.sqrt(1 - (1 - s / 0.12) ** 2) : 1
    return 0.2 * cap * (1 - s) ** 1.3
  }
  return patch({
    n: 72,
    m: 12,
    base: 0.024,
    raise: 0.016,
    sink: 0.03,
    bevel: [0.04, 0.08, 0.25, 0.25],
    domain: (s0, t) => {
      const s = s0 ** 1.3
      const c = centre.getPoint(s)
      const f = Math.max(0.04, c.y + (2 * t - 1) * halfWidth(s))
      const u = uAt(c.x)
      return [u, thetaAtHeight(u, f, side)]
    },
  })
}

/**
 * The heel label wraps around the centre-back seam: s runs from the −z side, through the
 * seam (u = 0) to the +z side; t runs up the back between two height fractions.
 */
const HEEL_LABEL: PatchSpec = {
  n: 80,
  m: 40,
  base: 0.022,
  raise: 0.016,
  sink: 0.004,
  bevel: [0.07, 0.07, 0.13, 0.13],
  domain: (s0, t) => {
    // Rounded corners: pull the side edges in near the top and bottom.
    const d = Math.min(t, 1 - t)
    const r = 0.24
    const squeeze = d < r ? 0.26 * (1 - Math.sqrt(1 - (1 - d / r) ** 2)) : 0
    const s = 0.5 + (s0 - 0.5) * (1 - squeeze)
    const side: 1 | -1 = s >= 0.5 ? 1 : -1
    const fraction = THREE.MathUtils.lerp(0.47, 0.85, t)
    const z = Math.abs(2 * s - 1) * 0.235
    let lo = X0
    let hi = -1.1
    for (let i = 0; i < 24; i++) {
      const x = (lo + hi) / 2
      const u = uAt(x)
      const p = surface(u, thetaAtHeight(u, fraction, side), new THREE.Vector3())
      if (Math.abs(p.z) < z) lo = x
      else hi = x
    }
    const u = uAt((lo + hi) / 2)
    return [u, thetaAtHeight(u, fraction, side)]
  },
}

function grainTexture(woven: boolean): THREE.CanvasTexture {
  const canvas = document.createElement('canvas')
  canvas.width = canvas.height = 256
  const ctx = canvas.getContext('2d')!
  const image = ctx.createImageData(256, 256)
  const rand = mulberry32(81)
  for (let y = 0; y < 256; y++) {
    for (let x = 0; x < 256; x++) {
      const i = (y * 256 + x) * 4
      const weave = woven ? 25 * Math.sin((x * Math.PI) / 3) * Math.cos((y * Math.PI) / 3) : 0
      const value = Math.round(128 + (rand() - 0.5) * 65 + weave)
      image.data[i] = image.data[i + 1] = image.data[i + 2] = value
      image.data[i + 3] = 255
    }
  }
  ctx.putImageData(image, 0, 0)
  const texture = new THREE.CanvasTexture(canvas)
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping
  texture.repeat.set(woven ? 3 : 5, woven ? 2 : 3)
  texture.anisotropy = 8
  return texture
}

function stitching(path: THREE.Vector3[], radius = 0.002): THREE.BufferGeometry {
  const curve = new THREE.CatmullRomCurve3(path)
  const length = curve.getLength()
  const count = Math.max(2, Math.floor(length / 0.025))
  const pieces: THREE.BufferGeometry[] = []
  for (let i = 0; i < count; i++) {
    const a = curve.getPointAt((i + 0.12) / count)
    const b = curve.getPointAt((i + 0.7) / count)
    pieces.push(new THREE.TubeGeometry(new THREE.LineCurve3(a, b), 1, radius, 4, false))
  }
  const result = mergeGeometries(pieces)
  pieces.forEach((piece) => piece.dispose())
  return result
}

// ---------------------------------------------------------------------------
// Assembly
// ---------------------------------------------------------------------------

export function buildSneaker(): SneakerModel {
  const root = new THREE.Group()
  const partMeshes = {} as Record<PartId, THREE.Mesh[]>
  const materials = {} as Record<PartId, THREE.MeshPhysicalMaterial>
  const leather = grainTexture(false)
  const textile = grainTexture(true)
  for (const id of PART_IDS) {
    partMeshes[id] = []
    materials[id] = new THREE.MeshPhysicalMaterial({ roughness: 0.6, metalness: 0 })
    materials[id].bumpMap = id === 'laces' || id === 'tongue' ? textile : leather
    materials[id].bumpScale = id === 'sole' || id === 'outsole' ? 0.001 : 0.0025
    materials[id].userData.bumpBase = materials[id].bumpScale
  }

  const trim = new THREE.MeshStandardMaterial({ color: 0x15161a, roughness: 0.75, metalness: 0 })
  const lining = new THREE.MeshStandardMaterial({ color: 0x1b1b1f, roughness: 0.95, metalness: 0 })
  const hardware = new THREE.MeshStandardMaterial({ color: 0x55564e, roughness: 0.7, metalness: 0.2 })
  const thread = new THREE.MeshStandardMaterial({ color: 0xc6c2b6, roughness: 0.92 })

  const add = (id: PartId, geometry: THREE.BufferGeometry, parent: THREE.Object3D = root): THREE.Mesh => {
    const mesh = new THREE.Mesh(geometry, materials[id])
    mesh.userData.partId = id
    partMeshes[id].push(mesh)
    parent.add(mesh)
    return mesh
  }
  const addMirrored = (id: PartId, build: (side: 1 | -1) => THREE.BufferGeometry): void => {
    add(id, build(1))
    add(id, build(-1))
  }

  // --- Sole unit -------------------------------------------------------------
  add('outsole', soleShell({ margin: 0.07, y0: 0, height: 0.075, rBottom: 0.035, rTop: 0.008 }))
  add(
    'sole',
    soleShell({ margin: 0.085, y0: 0.06, height: 0.17, rBottom: 0.012, rTop: 0.045, taper: 0.012, belly: 0.01 }),
  )
  // Moulded rib around the middle of the cupsole wall.
  const rib = footprintOutline(0.085, 90).map((p) => {
    const n = new THREE.Vector2(p.x - THREE.MathUtils.clamp(p.x, X0 + 0.34, X1 - 0.26), p.y).normalize()
    const q = p.clone().addScaledVector(n, 0.003)
    return new THREE.Vector3(q.x, 0.1 + lift(THREE.MathUtils.clamp(q.x, X0, X1)), q.y)
  })
  add('sole', new THREE.TubeGeometry(new THREE.CatmullRomCurve3(rib, true), 360, 0.0065, 8, true))
  const airMaterial = new THREE.MeshStandardMaterial({
    map: airTexture(),
    transparent: true,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    polygonOffsetUnits: -2,
    roughness: 0.8,
  })
  for (const side of [1, -1] as const) {
    const x = -0.78
    const slope = (footprint(x + 0.01, 0.085) - footprint(x - 0.01, 0.085)) / 0.02
    const air = new THREE.Mesh(new THREE.PlaneGeometry(0.17, 0.0425), airMaterial)
    air.position.set(x, 0.143, side * (footprint(x, 0.085) + 0.0024))
    air.rotation.y = Math.atan2(-slope * side, side)
    air.userData.partId = 'sole'
    air.userData.decal = true
    partMeshes.sole.push(air)
    root.add(air)
  }

  // Foxing lip: the cupsole wraps up over the bottom edge of the upper.
  add('sole', soleShell({ margin: 0.052, y0: BASE_Y - 0.06, height: 0.092, rBottom: 0.004, rTop: 0.014 }))

  // --- Upper (base) -----------------------------------------------------------
  add('upper', lastSurface(160, 72))

  // Padded collar ringing the foot opening, and the dark lining inside it.
  const deckY = baseY(OPEN_X) + HEIGHT(OPEN_X)
  const openRz = OPEN_RZ * WIDTH(OPEN_X)
  const collar = new THREE.TorusGeometry(0.3, 0.04, 16, 56)
  collar.rotateX(Math.PI / 2)
  collar.scale((OPEN_RX + 0.005) / 0.3, 1, (openRz + 0.005) / 0.3)
  collar.translate(OPEN_X, deckY - 0.032, 0)
  add('upper', collar)

  const opening = new THREE.Mesh(new THREE.CircleGeometry(1, 48), lining)
  opening.geometry.rotateX(-Math.PI / 2)
  opening.geometry.scale(OPEN_RX * 0.62, 1, openRz * 0.62)
  opening.position.set(OPEN_X, deckY - 0.13, 0)
  root.add(opening)

  // --- Overlays ---------------------------------------------------------------
  add('overlays', toeCap())
  add('overlays', heelCounter())
  addMirrored('overlays', mudguard)
  addMirrored('overlays', eyestay)
  addMirrored('stripe', swoosh)

  const seamPoint = (x: number, theta: number, offset: number) => {
    const u = uAt(x)
    const point = surface(u, theta, new THREE.Vector3())
    const normal = normalAt(u, theta, new THREE.Vector3())
    return point.addScaledVector(normal, offset)
  }
  const seam = (points: THREE.Vector3[]) => {
    const mesh = new THREE.Mesh(stitching(points), thread)
    root.add(mesh)
  }
  for (const shift of [0.04, 0.065]) {
    seam(
      Array.from({ length: 61 }, (_, i) => {
        const theta = THREE.MathUtils.lerp(0.18, Math.PI - 0.18, i / 60)
        return seamPoint(TOE_CAP_X - 0.08 * Math.sin(theta) + shift, theta, 0.031)
      }),
    )
  }
  for (const side of [1, -1] as const) {
    for (const fraction of [0.7, 0.92]) {
      seam(
        Array.from({ length: 61 }, (_, i) => {
          const x = THREE.MathUtils.lerp(-0.37, 0.75, i / 60)
          return seamPoint(x, thetaAtHeight(uAt(x), fraction, side), 0.027)
        }),
      )
    }
    seam(
      Array.from({ length: 71 }, (_, i) => {
        const x = THREE.MathUtils.lerp(-1.17, 1.3, i / 70)
        return new THREE.Vector3(x, 0.174 + lift(x), side * (footprint(x, 0.085) - 0.001))
      }),
    )
  }

  // Perforations across the toe box.
  const holeGeom = new THREE.CircleGeometry(0.012, 14)
  const holes: THREE.Matrix4[] = []
  const probe = new THREE.Object3D()
  for (const [row, x] of [0.97, 1.06, 1.15, 1.24].entries()) {
    const count = 7 - row
    for (let k = 0; k < count; k++) {
      const theta = THREE.MathUtils.lerp(0.75, Math.PI - 0.75, (k + 0.5) / count)
      placeOnLast(probe, uAt(x), theta, 0.0305)
      probe.updateMatrix()
      holes.push(probe.matrix.clone())
    }
  }
  const perforations = new THREE.InstancedMesh(holeGeom, trim, holes.length)
  holes.forEach((mtx, i) => perforations.setMatrixAt(i, mtx))
  root.add(perforations)

  // Eyelets punched into the eyestays.
  const eyeletGeom = new THREE.RingGeometry(0.018, 0.029, 18)
  const eyeletMesh = new THREE.InstancedMesh(eyeletGeom, hardware, EYELET_XS.length * 2)
  const eyelets: { pos: THREE.Vector3; nrm: THREE.Vector3 }[][] = [[], []]
  EYELET_XS.forEach((x, k) => {
    const u = uAt(x)
    for (const side of [1, -1] as const) {
      const theta = thetaAtHeight(u, EYELET_HEIGHT, side)
      placeOnLast(probe, u, theta, 0.026)
      probe.updateMatrix()
      eyeletMesh.setMatrixAt(k * 2 + (side === 1 ? 0 : 1), probe.matrix)
      const nrm = new THREE.Vector3()
      normalAt(u, theta, nrm)
      eyelets[side === 1 ? 0 : 1].push({ pos: probe.position.clone(), nrm })
    }
  })
  root.add(eyeletMesh)

  // --- Tongue -----------------------------------------------------------------
  const throatA = surface(uAt(-0.78), Math.PI / 2, new THREE.Vector3())
  const throatB = surface(uAt(0.7), Math.PI / 2, new THREE.Vector3())
  const throatDir = throatB.clone().sub(throatA)
  const tongueLen = throatDir.length() + 0.06
  const tongueTilt = Math.atan2(throatDir.y, throatDir.x) - 0.14
  const tongueThick = 0.1
  const tongue = new THREE.Group()
  tongue.position.copy(throatA).lerp(throatB, 0.5)
  tongue.position.y += 0.075
  tongue.rotation.z = tongueTilt
  root.add(tongue)
  add('tongue', new RoundedBoxGeometry(tongueLen, tongueThick, 0.46, 6, 0.046), tongue)
  const label = new THREE.Mesh(new RoundedBoxGeometry(0.2, 0.01, 0.2, 2, 0.005), trim)
  label.position.set(-tongueLen / 2 + 0.19, tongueThick / 2, 0)
  tongue.add(label)

  // --- Laces ------------------------------------------------------------------
  const laceWidth = 0.062
  const laceThick = 0.015
  const tongueTopAt = (x: number): number =>
    tongue.position.y + (x - tongue.position.x) * Math.tan(tongueTilt) + tongueThick / 2 / Math.cos(tongueTilt)
  const lace = (
    a: { pos: THREE.Vector3; nrm: THREE.Vector3 },
    b: { pos: THREE.Vector3; nrm: THREE.Vector3 },
    clearance: number,
  ) => {
    const from = a.pos.clone().addScaledVector(a.nrm, 0.004)
    const to = b.pos.clone().addScaledVector(b.nrm, 0.004)
    const mid = from.clone().lerp(to, 0.5)
    const midX = mid.x
    // Quadratic Bézier passes through (from + 2·ctrl + to) / 4 at its middle.
    const wantY = tongueTopAt(midX) + laceThick / 2 + clearance
    mid.y = 2 * wantY - (from.y + to.y) / 2
    const up = a.nrm
      .clone()
      .add(b.nrm)
      .add(new THREE.Vector3(0, 1.5, 0))
      .normalize()
    return ribbon(new THREE.QuadraticBezierCurve3(from, mid, to), up, laceWidth, laceThick)
  }
  for (let k = 0; k < EYELET_XS.length - 1; k++) {
    add('laces', lace(eyelets[0][k], eyelets[1][k + 1], 0.002))
    add('laces', lace(eyelets[1][k], eyelets[0][k + 1], laceThick + 0.004))
  }
  // Straight bar across the top pair of eyelets.
  add('laces', lace(eyelets[0][0], eyelets[1][0], 0.002))

  // --- Heel label -------------------------------------------------------------
  // A stitched leather label on the back of the heel counter that carries the engraving.
  add('heel', patch(HEEL_LABEL))
  const engravingMaterial = new THREE.MeshStandardMaterial({
    transparent: true,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    polygonOffsetUnits: -2,
    roughness: 0.75,
    metalness: 0,
  })
  const engraving = new THREE.Mesh(patchSkin(HEEL_LABEL, 0.0015), engravingMaterial)
  engraving.userData.partId = 'heel'
  engraving.userData.decal = true
  partMeshes.heel.push(engraving)
  root.add(engraving)

  root.position.y = -0.62
  return { root, partMeshes, materials, engravingMaterial }
}
