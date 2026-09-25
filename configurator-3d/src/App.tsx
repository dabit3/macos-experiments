import { useCallback, useEffect, useRef, useState } from 'react'
import { Sidebar } from './components/Sidebar'
import { Toolbar } from './components/Toolbar'
import { Icon } from './components/Icon'
import {
  DEFAULT_CONFIG,
  FINISH_LABELS,
  LOOKS,
  PALETTE,
  PART_IDS,
  PART_LABELS,
  VIEWS,
  decodeConfig,
  encodeConfig,
  randomConfig,
  type Finish,
  type LabelStyle,
  type PartId,
  type SneakerConfig,
  type ViewId,
} from './config'
import { SneakerViewer, type ViewerApi } from './scene/SneakerViewer'
import './App.css'

function initialConfig(): SneakerConfig {
  return decodeConfig(window.location.hash) ?? structuredClone(DEFAULT_CONFIG)
}

export default function App() {
  const [config, setConfig] = useState<SneakerConfig>(initialConfig)
  const [selected, setSelected] = useState<PartId | null>(null)
  const [hovered, setHovered] = useState<PartId | null>(null)
  const [customView, setCustomView] = useState(false)
  const [seed, setSeed] = useState(0)
  const [toast, setToast] = useState<string | null>(null)
  const [ready, setReady] = useState(false)
  const [section, setSection] = useState<'materials' | 'personalise' | 'save'>('materials')
  const [past, setPast] = useState<SneakerConfig[]>([])
  const [future, setFuture] = useState<SneakerConfig[]>([])
  const configRef = useRef(config)
  const lastEdit = useRef<{ key: string; at: number } | null>(null)
  const apiRef = useRef<ViewerApi | null>(null)
  const toastTimer = useRef<number | null>(null)

  const showToast = useCallback((message: string) => {
    setToast(message)
    if (toastTimer.current) window.clearTimeout(toastTimer.current)
    toastTimer.current = window.setTimeout(() => setToast(null), 2600)
  }, [])

  useEffect(() => {
    configRef.current = config
  }, [config])

  /**
   * Records a design change in the undo history. Rapid edits with the same `key` (typing,
   * dragging the colour picker) collapse into one step.
   */
  const commit = useCallback((update: (c: SneakerConfig) => SneakerConfig, key?: string) => {
    const current = configRef.current
    const next = update(current)
    if (encodeConfig(next) === encodeConfig(current)) return
    const now = performance.now()
    const last = lastEdit.current
    if (!(key && last && last.key === key && now - last.at < 900)) setPast((p) => [...p.slice(-59), current])
    lastEdit.current = key ? { key, at: now } : null
    setFuture([])
    configRef.current = next
    setConfig(next)
  }, [])

  const undo = useCallback(() => {
    const previous = past[past.length - 1]
    if (!previous) return
    const current = configRef.current
    setPast((p) => p.slice(0, -1))
    setFuture((f) => [current, ...f])
    lastEdit.current = null
    const next = { ...previous, view: current.view, spin: current.spin }
    configRef.current = next
    setConfig(next)
    showToast('Undone')
  }, [past, showToast])

  const redo = useCallback(() => {
    const upcoming = future[0]
    if (!upcoming) return
    const current = configRef.current
    setFuture((f) => f.slice(1))
    setPast((p) => [...p, current])
    lastEdit.current = null
    const next = { ...upcoming, view: current.view, spin: current.spin }
    configRef.current = next
    setConfig(next)
    showToast('Redone')
  }, [future, showToast])

  // Keep the URL hash in sync so the address bar is always a share link.
  const shareUrl = `${window.location.origin}${window.location.pathname}${encodeConfig(config)}`
  useEffect(() => {
    window.history.replaceState(null, '', encodeConfig(config))
  }, [config])

  // Jump straight to the saved view on first mount.
  const initialView = useRef(config.view)
  useEffect(() => {
    apiRef.current?.setView(initialView.current, false)
  }, [])

  // React to the hash being edited by hand / pasted while the app is open.
  useEffect(() => {
    const onHash = () => {
      const next = decodeConfig(window.location.hash)
      if (next) {
        setConfig(next)
        setCustomView(false)
        apiRef.current?.setView(next.view, true)
      }
    }
    window.addEventListener('hashchange', onHash)
    return () => window.removeEventListener('hashchange', onHash)
  }, [])

  const setView = useCallback((view: ViewId) => {
    setCustomView(false)
    apiRef.current?.setView(view, true)
    setConfig((c) => (c.view === view ? c : { ...c, view }))
  }, [])

  const updatePart = useCallback(
    (id: PartId, patch: Partial<{ color: string; finish: Finish }>, key?: string) => {
      setSelected(id)
      commit((c) => ({ ...c, parts: { ...c.parts, [id]: { ...c.parts[id], ...patch } } }), key)
    },
    [commit],
  )

  /** Selection from the 3D view: the part is already in shot, so the camera stays put. */
  const selectPart = useCallback((id: PartId | null) => {
    setSelected(id)
    if (id) setSection('materials')
  }, [])

  /** Selection from the panel or stepper: fly the camera to the part. */
  const focusPart = useCallback((id: PartId) => {
    setSelected(id)
    setSection('materials')
    setCustomView(true)
    apiRef.current?.focusPart(id)
  }, [])

  const stepPart = useCallback(
    (delta: 1 | -1) => {
      const index = selected ? PART_IDS.indexOf(selected) : delta === 1 ? -1 : 0
      focusPart(PART_IDS[(index + delta + PART_IDS.length) % PART_IDS.length])
    },
    [selected, focusPart],
  )

  const applyLook = useCallback(
    (id: string) => {
      const look = LOOKS.find((l) => l.id === id)
      if (!look) return
      commit((c) => ({ ...c, parts: structuredClone(look.parts) }))
      showToast(`${look.name} applied`)
    },
    [commit, showToast],
  )

  const updateLabel = useCallback(
    (patch: Partial<{ text: string; ink: string; label: LabelStyle }>) => {
      commit((c) => ({ ...c, ...patch }), patch.text !== undefined ? 'text' : undefined)
    },
    [commit],
  )

  const changeSection = (next: typeof section) => {
    setSection(next)
    setSelected(null)
    if (next === 'personalise') setView('heel')
  }

  const randomise = useCallback(() => {
    const next = seed + 1
    setSeed(next)
    commit((c) => randomConfig(next, c))
    showToast(`Randomised — seed #${next}`)
  }, [seed, commit, showToast])

  const reset = useCallback(() => {
    commit((c) => ({ ...structuredClone(DEFAULT_CONFIG), view: c.view, spin: c.spin }))
    showToast('Reset to the default colourway')
  }, [commit, showToast])

  const share = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(shareUrl)
      showToast('Share link copied to clipboard')
    } catch {
      showToast('Copy failed — select the link and copy it manually')
    }
  }, [shareUrl, showToast])

  const download = useCallback(() => {
    const api = apiRef.current
    if (!api) return
    const url = api.snapshot()
    const a = document.createElement('a')
    const slug = (config.text || 'custom').toLowerCase().replace(/[^a-z0-9]+/g, '-')
    a.href = url
    a.download = `sneaker-${slug}.png`
    a.click()
    showToast(`Saved ${a.download}`)
  }, [config.text, showToast])

  // Keyboard shortcuts (ignored while typing in a field).
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null
      const typing = target !== null && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)
      if ((e.ctrlKey || e.metaKey) && !e.altKey && !typing) {
        const k = e.key.toLowerCase()
        if (k === 'z' && !e.shiftKey) {
          e.preventDefault()
          undo()
        } else if ((k === 'z' && e.shiftKey) || k === 'y') {
          e.preventDefault()
          redo()
        }
        return
      }
      if (typing || (target && target.tagName === 'BUTTON')) return
      if (e.ctrlKey || e.metaKey || e.altKey) return
      if (e.key === 'Escape') setSelected(null)
      else if (e.key === 'ArrowRight' || e.key === ']') {
        e.preventDefault()
        stepPart(1)
      } else if (e.key === 'ArrowLeft' || e.key === '[') {
        e.preventDefault()
        stepPart(-1)
      }
      else if (e.key === ' ') {
        e.preventDefault()
        setConfig((c) => ({ ...c, spin: !c.spin }))
      } else if (e.key.toLowerCase() === 'r') randomise()
      else if (/^[1-4]$/.test(e.key)) setView(VIEWS[Number(e.key) - 1])
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [randomise, setView, undo, redo, stepPart])

  const status = selected ?? hovered
  const statusStyle = status ? config.parts[status] : null
  const editedParts = PART_IDS.filter(
    (id) =>
      config.parts[id].color !== DEFAULT_CONFIG.parts[id].color ||
      config.parts[id].finish !== DEFAULT_CONFIG.parts[id].finish,
  ).length

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
              <path
                d="M2.5 16.5c5.5-1.2 12.4-4 19-8.3-1.6 3.3-3.4 5.6-5.6 7.2-3.9 2.9-9.1 3.4-13.4 1.1z"
                fill="currentColor"
              />
            </svg>
          </span>
          <div>
            <h1>
              Kicks Lab<span> / BY YOU</span>
            </h1>
            <p>Independent design studio</p>
          </div>
        </div>
        <nav className="topbar-nav" aria-label="Studio">
          <span className="nav-item is-current">THE CUSTOM STUDIO</span>
          <span className="nav-item">VOL. 01 — COURT CLASSIC</span>
        </nav>
        <div className="topbar-actions">
          <div className="history" role="group" aria-label="History">
            <button
              type="button"
              className="icon-btn"
              onClick={undo}
              disabled={past.length === 0}
              title="Undo (Ctrl+Z)"
              aria-label="Undo"
              data-testid="undo"
            >
              <Icon name="undo" size={18} />
            </button>
            <button
              type="button"
              className="icon-btn"
              onClick={redo}
              disabled={future.length === 0}
              title="Redo (Ctrl+Shift+Z)"
              aria-label="Redo"
              data-testid="redo"
            >
              <Icon name="redo" size={18} />
            </button>
          </div>
          <button type="button" className="btn ghost" onClick={reset}>
            Reset
          </button>
          <button type="button" className="btn outline" onClick={randomise} title="Shortcut: R">
            <Icon name="shuffle" size={16} /> Randomise
          </button>
        </div>
      </header>

      <main className="workspace">
        <section className="viewer" aria-label="3D sneaker viewer">
          <SneakerViewer
            config={config}
            selected={selected}
            onSelect={selectPart}
            onHover={setHovered}
            onOrbit={() => setCustomView(true)}
            onReady={() => setReady(true)}
            apiRef={apiRef}
          />
          <div className="viewer-watermark" aria-hidden="true">
            COURT
          </div>
          <div className="viewer-title">
            <span className="eyebrow">
              <span className="live-dot" /> LIVE 3D STUDIO
            </span>
            <h2>
              A classic.
              <br />
              Your signature.
            </h2>
            <p>Built for the court. Made for you.</p>
          </div>
          <span className="viewer-edition" aria-hidden="true">
            CC—01
            <br />
            EST. 2026
          </span>
          <div className={`viewer-loading ${ready ? 'is-hidden' : ''}`} aria-hidden={ready}>
            <span className="spinner" />
            <span>Lacing up the scene…</span>
          </div>
          <div className="viewer-hint">
            <Icon name="orbit" size={18} />
            <span>
              Drag to rotate <i /> Scroll to zoom <i /> Click to customise
            </span>
          </div>
          <div
            className={`viewer-status ${status && !selected ? 'is-visible' : ''}`}
            data-testid="viewer-status"
          >
            {status && statusStyle ? (
              <>
                <span className="status-swatch" style={{ background: statusStyle.color }} />
                <span className="status-name">{PART_LABELS[status]}</span>
                <span className="status-meta">
                  {statusStyle.color.toUpperCase()} · {FINISH_LABELS[statusStyle.finish]}
                </span>
                <span className="status-kind">Click to edit</span>
              </>
            ) : null}
          </div>
          <div className={`quickbar ${selected ? 'is-visible' : ''}`} data-testid="quickbar" aria-hidden={!selected}>
            {selected ? (
              <>
                <button
                  type="button"
                  className="quick-step"
                  onClick={() => stepPart(-1)}
                  aria-label="Previous part"
                  title="Previous part (←)"
                >
                  <Icon name="chevronLeft" size={16} />
                </button>
                <div className="quick-part">
                  <small>
                    {String(PART_IDS.indexOf(selected) + 1).padStart(2, '0')} / 08
                  </small>
                  <strong>{PART_LABELS[selected]}</strong>
                </div>
                <button
                  type="button"
                  className="quick-step"
                  onClick={() => stepPart(1)}
                  aria-label="Next part"
                  title="Next part (→)"
                >
                  <Icon name="chevronRight" size={16} />
                </button>
                <div className="quick-swatches" role="group" aria-label={`${PART_LABELS[selected]} quick colours`}>
                  {PALETTE.map((p) => {
                    const on = config.parts[selected].color === p.hex
                    return (
                      <button
                        key={p.hex}
                        type="button"
                        className={`quick-swatch ${on ? 'is-active' : ''}`}
                        style={{ backgroundColor: p.hex }}
                        title={p.name}
                        aria-label={p.name}
                        aria-pressed={on}
                        onClick={() => updatePart(selected, { color: p.hex })}
                        data-testid={`quick-${p.name.toLowerCase().replace(/ /g, '-')}`}
                      />
                    )
                  })}
                </div>
                <button
                  type="button"
                  className="quick-close"
                  onClick={() => setSelected(null)}
                  aria-label="Done"
                  title="Done (Esc)"
                >
                  <Icon name="check" size={16} />
                </button>
              </>
            ) : null}
          </div>
          <Toolbar
            view={customView ? null : config.view}
            spin={config.spin}
            onView={setView}
            onToggleSpin={() => setConfig((c) => ({ ...c, spin: !c.spin }))}
          />
          <div className="stage-footer">
            <span>
              COURT CLASSIC LOW <b> / </b> UNISEX
            </span>
            <span>{String(editedParts).padStart(2, '0')} / 08 PANELS CUSTOMISED</span>
          </div>
        </section>

        <Sidebar
          config={config}
          selected={selected}
          onSelect={focusPart}
          onStep={stepPart}
          onLook={applyLook}
          section={section}
          onSection={changeSection}
          onUpdatePart={updatePart}
          onLabel={updateLabel}
          shareUrl={shareUrl}
          onShare={share}
          onDownload={download}
        />
      </main>

      <div className={`toast ${toast ? 'is-visible' : ''}`} role="status" aria-live="polite">
        {toast}
      </div>
    </div>
  )
}
