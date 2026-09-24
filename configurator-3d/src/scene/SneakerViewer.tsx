import { useEffect, useRef, type RefObject } from 'react'
import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js'
import { mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js'
import {
  PART_IDS,
  PART_LABELS,
  inkColor,
  type Finish,
  type LabelStyle,
  type PartId,
  type SneakerConfig,
  type ViewId,
} from '../config'
import { makeLabelTextures } from './engraving'
import { buildSneaker, footprintOutline, type SneakerModel } from './sneaker'

export interface ViewerApi {
  /** Fly the camera to one of the preset views. */
  setView: (view: ViewId, animate?: boolean) => void
  /** Fly the camera to the angle that best shows one part. */
  focusPart: (part: PartId) => void
  /** Render a clean full-resolution frame (no outlines) and return it as a PNG data URL. */
  snapshot: () => string
}

interface Props {
  config: SneakerConfig
  selected: PartId | null
  onSelect: (part: PartId | null) => void
  onHover: (part: PartId | null) => void
  /** Fired when the user orbits manually, so the app can mark the view as "custom". */
  onOrbit: () => void
  /** Fired once the first frame has been drawn (shader compilation can take a moment). */
  onReady: () => void
  apiRef: RefObject<ViewerApi | null>
}

const TARGET = new THREE.Vector3(0.05, 0.02, 0)

const VIEW_POSITIONS: Record<ViewId, THREE.Vector3> = {
  hero: new THREE.Vector3(2.6, 1.9, 4.2),
  side: new THREE.Vector3(0.05, 0.5, 4.8),
  heel: new THREE.Vector3(-5.1, 0.7, 0),
  top: new THREE.Vector3(0.05, 4.8, 0.5),
}

const PART_SHOTS: Record<PartId, THREE.Vector3> = {
  upper: new THREE.Vector3(1.3, 1.25, 4.6),
  overlays: new THREE.Vector3(3.6, 1.5, 3.0),
  stripe: new THREE.Vector3(0.35, 0.75, 4.85),
  laces: new THREE.Vector3(2.4, 3.8, 1.9),
  tongue: new THREE.Vector3(3.3, 2.9, 1.5),
  heel: new THREE.Vector3(-5.1, 0.7, 0),
  sole: new THREE.Vector3(1.0, 0.3, 4.85),
  outsole: new THREE.Vector3(3.0, 0.08, 3.8),
}

// Software/low-end GPUs: draw at reduced resolution while the camera moves,
// then settle on a crisp full-resolution frame once everything is still.
const MOTION_SCALE = 0.5
const IDLE_SCALE = 1

const SELECT_COLOR = new THREE.Color('#ff5a1f')
const HOVER_COLOR = new THREE.Color('#111111')

interface Rig {
  renderer: THREE.WebGLRenderer
  scene: THREE.Scene
  camera: THREE.PerspectiveCamera
  controls: OrbitControls
  model: SneakerModel
  environment: THREE.Texture
  raycaster: THREE.Raycaster
  hull: Record<PartId, THREE.Mesh[]>
  hullMaterial: THREE.MeshBasicMaterial
  hovered: PartId | null
  selected: PartId | null
  tween: { from: THREE.Vector3; to: THREE.Vector3; start: number; duration: number } | null
  /** Set when something changed and a frame must be drawn. */
  dirty: boolean
  /** Colour each part material is easing towards. */
  targets: Record<PartId, THREE.Color>
  /** Current render scale (pixel ratio); dropped while the camera moves. */
  scale: number
  dispose: () => void
}

/**
 * Matte is full-grain leather with a soft sheen; suede is napped and velvety; gloss is patent
 * leather under a clear coat; metallic is a brushed foil with the environment doing the work.
 */
function applyFinish(mat: THREE.MeshPhysicalMaterial, finish: Finish, env: THREE.Texture): void {
  mat.envMap = env
  mat.clearcoat = 0
  mat.clearcoatRoughness = 0
  mat.sheen = 0
  mat.metalness = 0
  switch (finish) {
    case 'matte':
      mat.roughness = 0.62
      mat.envMapIntensity = 0.45
      mat.sheen = 0.35
      mat.sheenRoughness = 0.6
      mat.sheenColor.set(0xffffff)
      break
    case 'suede':
      mat.roughness = 1
      mat.envMapIntensity = 0.2
      mat.sheen = 1
      mat.sheenRoughness = 0.35
      mat.sheenColor.set(0xd9d4c8)
      break
    case 'gloss':
      mat.roughness = 0.3
      mat.envMapIntensity = 0.3
      mat.clearcoat = 0.7
      mat.clearcoatRoughness = 0.1
      break
    case 'metallic':
      mat.roughness = 0.3
      mat.metalness = 0.92
      mat.envMapIntensity = 1.15
      break
  }
  mat.bumpScale = finish === 'suede' ? 0.006 : mat.userData.bumpBase
  mat.needsUpdate = true
}

function applyLabelStyle(mat: THREE.MeshStandardMaterial, style: LabelStyle, env: THREE.Texture): void {
  mat.envMap = env
  mat.metalness = style === 'foil' ? 1 : 0
  mat.roughness = style === 'foil' ? 0.26 : style === 'embroidered' ? 0.55 : 0.7
  mat.envMapIntensity = style === 'foil' ? 1.4 : 0.5
  mat.needsUpdate = true
}

function easeInOutCubic(t: number): number {
  return t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2
}

function pickPart(hits: THREE.Intersection[]): PartId | null {
  for (const hit of hits) {
    const id = hit.object.userData.partId
    if (typeof id === 'string' && (PART_IDS as readonly string[]).includes(id)) return id as PartId
  }
  return null
}

/**
 * Contact shadow baked from the sole footprint: a tight dark core under the sole and a wide
 * soft penumbra, so the shoe sits on the stage without a shadow-map pass.
 */
function makeContactShadow(): THREE.Mesh {
  const W = 1024
  const H = 512
  const spanX = 4.4
  const spanZ = 2.2
  const canvas = document.createElement('canvas')
  canvas.width = W
  canvas.height = H
  const ctx = canvas.getContext('2d')
  const outline = footprintOutline(0.08)
  const trace = (grow: number) => {
    if (!ctx) return
    ctx.beginPath()
    outline.forEach((p, i) => {
      const x = ((p.x + spanX / 2) / spanX) * W
      const y = ((p.y * (1 + grow) + spanZ / 2) / spanZ) * H
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    })
    ctx.closePath()
    ctx.fill()
  }
  if (ctx) {
    ctx.fillStyle = 'rgba(20,22,18,0.16)'
    ctx.filter = 'blur(38px)'
    trace(0.35)
    ctx.fillStyle = 'rgba(20,22,18,0.3)'
    ctx.filter = 'blur(14px)'
    trace(0.08)
    ctx.fillStyle = 'rgba(10,10,8,0.45)'
    ctx.filter = 'blur(5px)'
    trace(-0.04)
  }
  const tex = new THREE.CanvasTexture(canvas)
  const mesh = new THREE.Mesh(
    new THREE.PlaneGeometry(spanX, spanZ),
    new THREE.MeshBasicMaterial({ map: tex, transparent: true, depthWrite: false }),
  )
  mesh.rotation.x = -Math.PI / 2
  mesh.position.set(0, -0.618, 0)
  mesh.renderOrder = -1
  return mesh
}

/**
 * Inverted-hull outline material: back faces pushed out along smooth vertex normals in a flat
 * colour. Far cheaper than a post-processing outline pass, which matters on software WebGL.
 */
function makeHullMaterial(): THREE.MeshBasicMaterial {
  const mat = new THREE.MeshBasicMaterial({ color: SELECT_COLOR, side: THREE.BackSide, toneMapped: false })
  mat.onBeforeCompile = (shader) => {
    shader.vertexShader = shader.vertexShader.replace(
      '#include <begin_vertex>',
      'vec3 transformed = position + normal * 0.012;',
    )
  }
  return mat
}

function buildHulls(model: SneakerModel, material: THREE.MeshBasicMaterial): Record<PartId, THREE.Mesh[]> {
  const smoothed = new Map<THREE.BufferGeometry, THREE.BufferGeometry>()
  const hull = {} as Record<PartId, THREE.Mesh[]>
  for (const id of PART_IDS) {
    hull[id] = model.partMeshes[id]
      .filter((m) => m.userData.decal !== true)
      .map((m) => {
        let geom = smoothed.get(m.geometry)
        if (!geom) {
          geom = mergeVertices(m.geometry, 1e-4)
          geom.computeVertexNormals()
          smoothed.set(m.geometry, geom)
        }
        const h = new THREE.Mesh(geom, material)
        h.visible = false
        h.raycast = () => {}
        h.position.copy(m.position)
        h.rotation.copy(m.rotation)
        h.scale.copy(m.scale)
        m.parent?.add(h)
        return h
      })
  }
  return hull
}

function refreshHulls(rig: Rig): void {
  rig.hullMaterial.color.copy(rig.selected ? SELECT_COLOR : HOVER_COLOR)
  for (const id of PART_IDS) {
    const show = id === rig.selected || (rig.selected === null && id === rig.hovered)
    for (const h of rig.hull[id]) h.visible = show
  }
  rig.dirty = true
}

function createRig(container: HTMLDivElement): Rig {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' })
  renderer.setClearColor(0x000000, 0)
  renderer.toneMapping = THREE.NeutralToneMapping
  renderer.toneMappingExposure = 0.92
  container.appendChild(renderer.domElement)

  const scene = new THREE.Scene()
  const pmrem = new THREE.PMREMGenerator(renderer)
  const environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture
  pmrem.dispose()

  const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100)
  camera.position.copy(VIEW_POSITIONS.hero)
  camera.lookAt(TARGET)

  const controls = new OrbitControls(camera, renderer.domElement)
  controls.target.copy(TARGET)
  controls.enableDamping = true
  controls.dampingFactor = 0.1
  controls.minDistance = 2.4
  controls.maxDistance = 9
  controls.maxPolarAngle = Math.PI * 0.52
  controls.enablePan = false
  controls.autoRotateSpeed = 2.2

  // Studio setup: large soft key high front-right, cool fill from the back-left, a low rim
  // grazing the heel, and a bright hemisphere so shadows stay open like a product shoot.
  const key = new THREE.DirectionalLight(0xfff9f0, 1.45)
  key.position.set(3, 5.5, 3.5)
  scene.add(key)
  const fill = new THREE.DirectionalLight(0xe4eaff, 0.65)
  fill.position.set(-4, 2.5, -3)
  scene.add(fill)
  const rim = new THREE.DirectionalLight(0xffffff, 0.55)
  rim.position.set(-3, 1.2, 4)
  scene.add(rim)
  const top = new THREE.DirectionalLight(0xffffff, 0.45)
  top.position.set(0, 6, -1)
  scene.add(top)
  scene.add(new THREE.HemisphereLight(0xffffff, 0xb8b3a5, 0.8))

  scene.add(makeContactShadow())

  const model = buildSneaker()
  scene.add(model.root)

  const hullMaterial = makeHullMaterial()
  const hull = buildHulls(model, hullMaterial)

  const dispose = () => {
    const textures = new Set<THREE.Texture>([environment])
    controls.dispose()
    renderer.dispose()
    scene.traverse((obj) => {
      if (obj instanceof THREE.Mesh) {
        obj.geometry.dispose()
        const mats = Array.isArray(obj.material) ? obj.material : [obj.material]
        mats.forEach((m) => {
          if (m instanceof THREE.MeshStandardMaterial || m instanceof THREE.MeshBasicMaterial) {
            if (m.map) textures.add(m.map)
          }
          if (m instanceof THREE.MeshStandardMaterial && m.bumpMap) textures.add(m.bumpMap)
          m.dispose()
        })
      }
    })
    textures.forEach((texture) => texture.dispose())
    renderer.domElement.remove()
  }

  return {
    renderer,
    scene,
    camera,
    controls,
    model,
    environment,
    raycaster: new THREE.Raycaster(),
    hull,
    hullMaterial,
    hovered: null,
    selected: null,
    tween: null,
    dirty: true,
    targets: Object.fromEntries(PART_IDS.map((id) => [id, model.materials[id].color.clone()])) as Record<
      PartId,
      THREE.Color
    >,
    scale: IDLE_SCALE,
    dispose,
  }
}

export function SneakerViewer({ config, selected, onSelect, onHover, onOrbit, onReady, apiRef }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const tipRef = useRef<HTMLDivElement>(null)
  const rigRef = useRef<Rig | null>(null)
  const callbacks = useRef({ onSelect, onHover, onOrbit, onReady })
  useEffect(() => {
    callbacks.current = { onSelect, onHover, onOrbit, onReady }
  }, [onSelect, onHover, onOrbit, onReady])

  // Build the scene once.
  useEffect(() => {
    const container = containerRef.current
    if (!container) return
    const rig = createRig(container)
    rigRef.current = rig

    const setScale = (scale: number) => {
      if (rig.scale === scale) return
      rig.scale = scale
      const { clientWidth: w, clientHeight: h } = container
      rig.renderer.setPixelRatio(scale)
      rig.renderer.setSize(w, h, false)
    }
    const resize = () => {
      const { clientWidth: w, clientHeight: h } = container
      if (w === 0 || h === 0) return
      rig.camera.aspect = w / h
      rig.camera.fov = THREE.MathUtils.radToDeg(
        2 * Math.atan(Math.tan(THREE.MathUtils.degToRad(19)) * Math.max(1, 1.15 / rig.camera.aspect)),
      )
      rig.camera.updateProjectionMatrix()
      rig.renderer.setPixelRatio(rig.scale)
      rig.renderer.setSize(w, h, false)
      rig.dirty = true
    }
    resize()
    const ro = new ResizeObserver(resize)
    ro.observe(container)

    const allMeshes = (Object.values(rig.model.partMeshes) as THREE.Mesh[][]).flat()
    const pointer = new THREE.Vector2()
    const toNdc = (e: PointerEvent) => {
      const rect = rig.renderer.domElement.getBoundingClientRect()
      pointer.set(((e.clientX - rect.left) / rect.width) * 2 - 1, -((e.clientY - rect.top) / rect.height) * 2 + 1)
    }
    const castAt = (e: PointerEvent): PartId | null => {
      toNdc(e)
      rig.raycaster.setFromCamera(pointer, rig.camera)
      return pickPart(rig.raycaster.intersectObjects(allMeshes, false))
    }

    let down: { x: number; y: number; t: number } | null = null
    const setHovered = (part: PartId | null) => {
      if (part === rig.hovered) return
      rig.hovered = part
      rig.renderer.domElement.style.cursor = part ? 'pointer' : 'grab'
      refreshHulls(rig)
      callbacks.current.onHover(part)
    }

    const el = rig.renderer.domElement
    const onPointerDown = (e: PointerEvent) => {
      if (e.button !== 0) return
      down = { x: e.clientX, y: e.clientY, t: performance.now() }
      el.style.cursor = 'grabbing'
    }
    const moveTip = (e: PointerEvent) => {
      const tip = tipRef.current
      if (!tip) return
      const rect = container.getBoundingClientRect()
      tip.style.transform = `translate(${e.clientX - rect.left + 16}px, ${e.clientY - rect.top + 18}px)`
      tip.textContent = rig.hovered ? PART_LABELS[rig.hovered] : ''
      tip.classList.toggle('is-visible', rig.hovered !== null && rig.hovered !== rig.selected && !down)
    }
    const onPointerMove = (e: PointerEvent) => {
      moveTip(e)
      if (down) {
        if (Math.hypot(e.clientX - down.x, e.clientY - down.y) > 6) {
          rig.tween = null
          callbacks.current.onOrbit()
          setHovered(null)
        }
        return
      }
      setHovered(castAt(e))
      moveTip(e)
    }
    const onPointerUp = (e: PointerEvent) => {
      if (!down) return
      const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y)
      const elapsed = performance.now() - down.t
      down = null
      el.style.cursor = rig.hovered ? 'pointer' : 'grab'
      if (moved <= 6 && elapsed < 600) callbacks.current.onSelect(castAt(e))
    }
    const onPointerLeave = () => {
      setHovered(null)
      tipRef.current?.classList.remove('is-visible')
    }
    el.addEventListener('pointerdown', onPointerDown)
    el.addEventListener('pointermove', onPointerMove)
    el.addEventListener('pointerup', onPointerUp)
    el.addEventListener('pointerleave', onPointerLeave)
    el.style.cursor = 'grab'

    let lastCameraMove = 0
    const onControlsChange = () => {
      rig.dirty = true
      lastCameraMove = performance.now()
    }
    rig.controls.addEventListener('change', onControlsChange)

    let frame = 0
    let ready = false
    const loop = (now: number) => {
      frame = requestAnimationFrame(loop)
      const t = rig.tween
      if (t) {
        const k = Math.min(1, (now - t.start) / t.duration)
        rig.camera.position.lerpVectors(t.from, t.to, easeInOutCubic(k))
        if (k >= 1) rig.tween = null
        rig.dirty = true
        lastCameraMove = now
      }
      rig.controls.update()
      for (const id of PART_IDS) {
        const c = rig.model.materials[id].color
        const target = rig.targets[id]
        if (c.equals(target)) continue
        c.lerp(target, 0.2)
        if (Math.abs(c.r - target.r) + Math.abs(c.g - target.g) + Math.abs(c.b - target.b) < 0.004) c.copy(target)
        rig.dirty = true
      }
      const moving = rig.tween !== null || rig.controls.autoRotate || now - lastCameraMove < 160
      if (moving) {
        setScale(MOTION_SCALE)
        rig.dirty = true
      } else if (rig.scale !== IDLE_SCALE) {
        setScale(IDLE_SCALE)
        rig.dirty = true
      }
      if (!rig.dirty) return
      rig.dirty = false
      rig.renderer.render(rig.scene, rig.camera)
      if (!ready) {
        ready = true
        callbacks.current.onReady()
      }
    }
    frame = requestAnimationFrame(loop)

    apiRef.current = {
      setView: (view, animate = true) => {
        const to = VIEW_POSITIONS[view]
        if (!animate) {
          rig.camera.position.copy(to)
          rig.tween = null
          rig.dirty = true
          return
        }
        rig.tween = { from: rig.camera.position.clone(), to, start: performance.now(), duration: 750 }
      },
      focusPart: (part) => {
        const to = PART_SHOTS[part]
        if (rig.camera.position.distanceTo(to) < 0.05) return
        rig.tween = { from: rig.camera.position.clone(), to, start: performance.now(), duration: 850 }
      },
      snapshot: () => {
        const shown = (Object.values(rig.hull) as THREE.Mesh[][]).flat().filter((h) => h.visible)
        shown.forEach((h) => (h.visible = false))
        setScale(IDLE_SCALE)
        rig.renderer.render(rig.scene, rig.camera)
        const url = rig.renderer.domElement.toDataURL('image/png')
        shown.forEach((h) => (h.visible = true))
        rig.dirty = true
        return url
      },
    }

    return () => {
      cancelAnimationFrame(frame)
      ro.disconnect()
      rig.controls.removeEventListener('change', onControlsChange)
      el.removeEventListener('pointerdown', onPointerDown)
      el.removeEventListener('pointermove', onPointerMove)
      el.removeEventListener('pointerup', onPointerUp)
      el.removeEventListener('pointerleave', onPointerLeave)
      apiRef.current = null
      rig.dispose()
      rigRef.current = null
    }
  }, [apiRef])

  // Part colours + finishes.
  useEffect(() => {
    const rig = rigRef.current
    if (!rig) return
    for (const id of PART_IDS) {
      const { color, finish } = config.parts[id]
      rig.targets[id].set(color)
      applyFinish(rig.model.materials[id], finish, rig.environment)
    }
    rig.dirty = true
  }, [config.parts])

  // Heel label artwork: colour layer on the decal, relief on the label leather itself.
  const tabColor = config.parts.heel.color
  useEffect(() => {
    const rig = rigRef.current
    if (!rig) return
    const { map, bump } = makeLabelTextures(config.text, inkColor(config.ink, tabColor), config.label)
    map.userData.label = true
    bump.userData.label = true
    const decal = rig.model.engravingMaterial
    const leather = rig.model.materials.heel
    const old = [decal.map, leather.bumpMap]
    decal.map = map
    applyLabelStyle(decal, config.label, rig.environment)
    leather.bumpMap = bump
    leather.userData.bumpBase = 0.012
    leather.bumpScale = 0.012
    leather.needsUpdate = true
    old.forEach((t) => t?.userData.label && t.dispose())
    rig.dirty = true
  }, [config.text, config.ink, config.label, tabColor])

  // Autorotate.
  useEffect(() => {
    const rig = rigRef.current
    if (!rig) return
    rig.controls.autoRotate = config.spin
    rig.dirty = true
  }, [config.spin])

  // Selection outline.
  useEffect(() => {
    const rig = rigRef.current
    if (!rig) return
    rig.selected = selected
    refreshHulls(rig)
  }, [selected])

  return (
    <div ref={containerRef} className="viewer-canvas">
      <div ref={tipRef} className="part-tip" aria-hidden="true" />
    </div>
  )
}
