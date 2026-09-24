import { useMemo, useState } from 'react'
import {
  FINISHES,
  FINISH_LABELS,
  LABEL_STYLES,
  LABEL_STYLE_LABELS,
  LOOKS,
  MAX_TEXT,
  PALETTE,
  PART_HINTS,
  PART_IDS,
  PART_LABELS,
  normalizeHex,
  relativeLuminance,
  sanitizeText,
  THREADS,
  inkColor,
  type Finish,
  type LabelStyle,
  type PartId,
  type SneakerConfig,
} from '../config'
import { LABEL_H, LABEL_W, drawLabel } from '../scene/engraving'
import { Icon } from './Icon'

type Section = 'materials' | 'personalise' | 'save'

interface Props {
  config: SneakerConfig
  selected: PartId | null
  section: Section
  onSection: (section: Section) => void
  onSelect: (part: PartId) => void
  onStep: (delta: 1 | -1) => void
  onLook: (id: string) => void
  onUpdatePart: (part: PartId, patch: Partial<{ color: string; finish: Finish }>, key?: string) => void
  onLabel: (patch: Partial<{ text: string; ink: string; label: LabelStyle }>) => void
  shareUrl: string
  onShare: () => void
  onDownload: () => void
}

const SECTIONS = ['materials', 'personalise', 'save'] as const
const SECTION_LABELS = { materials: 'Materials', personalise: 'Personalise', save: 'Your design' }
const FINISH_HINTS = { matte: 'Soft leather', suede: 'Napped velvet', gloss: 'Patent shine', metallic: 'Brushed foil' }
const LABEL_HINTS = { embroidered: 'Satin thread', debossed: 'Pressed leather', foil: 'Hot-stamped' }

/** The heel label as it renders on the shoe, flattened onto the tab colour. */
function useLabelPreview(text: string, ink: string, style: LabelStyle, tab: string): string {
  return useMemo(() => {
    const art = drawLabel(text, inkColor(ink, tab), style)
    const c = document.createElement('canvas')
    c.width = LABEL_W
    c.height = LABEL_H
    const ctx = c.getContext('2d')
    if (!ctx) return ''
    ctx.fillStyle = tab
    ctx.beginPath()
    ctx.roundRect(0, 0, LABEL_W, LABEL_H, 70)
    ctx.fill()
    const sheen = ctx.createLinearGradient(0, 0, 0, LABEL_H)
    sheen.addColorStop(0, 'rgba(255,255,255,0.14)')
    sheen.addColorStop(0.5, 'rgba(255,255,255,0)')
    sheen.addColorStop(1, 'rgba(0,0,0,0.14)')
    ctx.fillStyle = sheen
    ctx.fill()
    ctx.drawImage(art.color, 0, 0)
    return c.toDataURL('image/png')
  }, [text, ink, style, tab])
}

export function Sidebar({
  config,
  selected,
  section,
  onSection,
  onSelect,
  onStep,
  onLook,
  onUpdatePart,
  onLabel,
  shareUrl,
  onShare,
  onDownload,
}: Props) {
  const id = selected ?? 'upper'
  const current = config.parts[id]
  const index = PART_IDS.indexOf(id)
  const labelPreview = useLabelPreview(config.text, config.ink, config.label, config.parts.heel.color)
  const activeLook = LOOKS.find((look) =>
    PART_IDS.every(
      (p) => look.parts[p].color === config.parts[p].color && look.parts[p].finish === config.parts[p].finish,
    ),
  )
  const [hexDraft, setHexDraft] = useState<{ part: PartId; base: string; value: string } | null>(null)
  const hexValue = hexDraft?.part === id && hexDraft.base === current.color ? hexDraft.value : current.color
  const colorName = PALETTE.find((p) => p.hex === current.color)?.name ?? 'Custom colour'
  const commitHex = () => {
    const hex = normalizeHex(hexValue)
    if (hex) onUpdatePart(id, { color: hex })
    setHexDraft(null)
  }

  return (
    <aside className="sidebar" aria-label="Customise your sneaker">
      <header className="product-intro">
        <div className="product-kicker">
          <span>YOUR ONE OF ONE</span>
          <span>01 / LOW TOP</span>
        </div>
        <h2>
          Court Classic<span>By you.</span>
        </h2>
        <p>An icon is just the beginning. Make it yours.</p>
      </header>
      <div className="studio-tabs" role="tablist" aria-label="Design steps">
        {SECTIONS.map((tab, i) => (
          <button
            key={tab}
            type="button"
            role="tab"
            id={`tab-${tab}`}
            aria-controls={`panel-${tab}`}
            aria-selected={section === tab}
            onClick={() => onSection(tab)}
            className={section === tab ? 'is-active' : ''}
            onKeyDown={(e) => {
              if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return
              e.preventDefault()
              const next = SECTIONS[(i + (e.key === 'ArrowRight' ? 1 : 2)) % SECTIONS.length]
              onSection(next)
              document.getElementById(`tab-${next}`)?.focus()
            }}
            tabIndex={section === tab ? 0 : -1}
          >
            <span>0{i + 1}</span>
            {SECTION_LABELS[tab]}
          </button>
        ))}
      </div>

      <div className="sidebar-content" id={`panel-${section}`} role="tabpanel" aria-labelledby={`tab-${section}`}>
        {section === 'materials' && (
          <>
            <section className="panel">
              <header className="panel-head">
                <h3>Start from an icon</h3>
                <span>{activeLook ? activeLook.name : 'Custom'}</span>
              </header>
              <div className="look-strip" role="group" aria-label="Curated colourways">
                {LOOKS.map((look) => (
                  <button
                    key={look.id}
                    type="button"
                    className={`look-card ${activeLook?.id === look.id ? 'is-active' : ''}`}
                    aria-pressed={activeLook?.id === look.id}
                    onClick={() => onLook(look.id)}
                    data-testid={`look-${look.id}`}
                  >
                    <span className="look-chips" aria-hidden="true">
                      {(['upper', 'overlays', 'stripe', 'sole', 'outsole'] as const).map((p) => (
                        <i key={p} style={{ backgroundColor: look.parts[p].color }} />
                      ))}
                    </span>
                    <span className="look-name">{look.name}</span>
                  </button>
                ))}
              </div>
            </section>
            <section className="panel stepper-panel">
              <div className="part-stepper">
                <button type="button" className="step-btn" onClick={() => onStep(-1)} aria-label="Previous part">
                  <Icon name="chevronLeft" size={18} />
                </button>
                <div className="step-title">
                  <small>
                    Step {String(index + 1).padStart(2, '0')} of 08 · {PART_HINTS[id]}
                  </small>
                  <strong data-testid="active-part">{PART_LABELS[id]}</strong>
                </div>
                <button type="button" className="step-btn" onClick={() => onStep(1)} aria-label="Next part">
                  <Icon name="chevronRight" size={18} />
                </button>
              </div>
              <div className="step-progress" aria-hidden="true">
                {PART_IDS.map((p, i) => (
                  <i key={p} className={i <= index ? 'is-done' : ''} />
                ))}
              </div>
              <ul className="part-list">
                {PART_IDS.map((part) => {
                  const style = config.parts[part]
                  return (
                    <li key={part}>
                      <button
                        type="button"
                        className={`part-row ${id === part ? 'is-active' : ''}`}
                        aria-pressed={id === part}
                        onClick={() => onSelect(part)}
                        data-testid={`part-${part}`}
                        title={`${PART_HINTS[part]} · ${style.color.toUpperCase()} · ${FINISH_LABELS[style.finish]}`}
                      >
                        <span
                          className={`part-swatch finish-${style.finish}`}
                          style={{ backgroundColor: style.color }}
                        />
                        <span className="part-name">{PART_LABELS[part]}</span>
                        {id === part && <Icon name="check" size={14} />}
                      </button>
                    </li>
                  )
                })}
              </ul>
            </section>
            <section className="panel">
              <header className="panel-head">
                <h3>{PART_LABELS[id]} colour</h3>
                <span>{colorName}</span>
              </header>
              <div className="swatch-grid" role="group" aria-label="Colour swatches">
                {PALETTE.map((p) => (
                  <button
                    key={p.hex}
                    type="button"
                    aria-pressed={current.color === p.hex}
                    className={`swatch ${current.color === p.hex ? 'is-active' : ''}`}
                    style={{ backgroundColor: p.hex, color: relativeLuminance(p.hex) > 0.35 ? '#111' : '#fff' }}
                    title={`${p.name} ${p.hex.toUpperCase()}`}
                    onClick={() => onUpdatePart(id, { color: p.hex })}
                    data-testid={`swatch-${p.name.toLowerCase()}`}
                  >
                    {current.color === p.hex && <Icon name="check" size={16} />}
                    <span className="sr-only">{p.name}</span>
                  </button>
                ))}
              </div>
              <div className="colour-row">
                <label className="colour-input">
                  <input
                    type="color"
                    value={current.color}
                    onChange={(e) => onUpdatePart(id, { color: e.target.value }, `picker-${id}`)}
                    aria-label="Custom colour picker"
                  />
                  Custom colour
                </label>
                <input
                  className="hex-input"
                  type="text"
                  value={hexValue}
                  spellCheck={false}
                  maxLength={7}
                  onChange={(e) => setHexDraft({ part: id, base: current.color, value: e.target.value })}
                  onBlur={commitHex}
                  onKeyDown={(e) => e.key === 'Enter' && commitHex()}
                  aria-label="Hex colour"
                  data-testid="hex-input"
                />
              </div>
            </section>
            <section className="panel">
              <header className="panel-head">
                <h3>The finishing touch</h3>
                <span>{FINISH_LABELS[current.finish]}</span>
              </header>
              <div className="finish-options" role="group" aria-label="Material finish">
                {FINISHES.map((finish) => (
                  <button
                    key={finish}
                    type="button"
                    className={`finish-option ${current.finish === finish ? 'is-active' : ''}`}
                    aria-pressed={current.finish === finish}
                    onClick={() => onUpdatePart(id, { finish })}
                    data-testid={`finish-${finish}`}
                  >
                    <span className={`material-sphere finish-${finish}`} aria-hidden="true" />
                    <strong>{FINISH_LABELS[finish]}</strong>
                    <small>{FINISH_HINTS[finish]}</small>
                  </button>
                ))}
              </div>
              <button
                type="button"
                className="next-step"
                onClick={() => (index === PART_IDS.length - 1 ? onSection('personalise') : onStep(1))}
                data-testid="next-step"
              >
                <span>
                  <small>Next</small>
                  {index === PART_IDS.length - 1 ? 'Personalise the heel' : PART_LABELS[PART_IDS[index + 1]]}
                </span>
                <Icon name="arrow" size={18} />
              </button>
            </section>
          </>
        )}
        {section === 'personalise' && (
          <section className="personalise-panel">
            <span className="eyebrow">THE DETAIL THAT MAKES IT YOURS</span>
            <h3>Leave your mark.</h3>
            <p>A name, a number, a reminder — finished on the heel tab by hand.</p>
            <figure className="label-preview" data-testid="label-preview">
              <img src={labelPreview} alt={`Heel label preview: ${config.text || 'brand mark'}`} />
              <figcaption>
                {LABEL_STYLE_LABELS[config.label]} · {config.text || 'Brand mark'}
              </figcaption>
            </figure>
            <label className="field-label" htmlFor="engraving">
              Your text <span>UP TO 8 CHARACTERS</span>
            </label>
            <div className="engrave-row">
              <input
                id="engraving"
                className="engrave-input"
                type="text"
                value={config.text}
                maxLength={MAX_TEXT}
                placeholder="YOUR NAME"
                spellCheck={false}
                autoComplete="off"
                onChange={(e) => onLabel({ text: sanitizeText(e.target.value) })}
                aria-label="Engraving text"
                data-testid="engrave-input"
              />
              <span className="counter">
                {config.text.length}/{MAX_TEXT}
              </span>
            </div>
            <p className="field-help">Letters, numbers, spaces and . - &amp; ! · Leave empty for the brand mark.</p>

            <div className="field-label">Technique</div>
            <div className="label-styles" role="group" aria-label="Label technique">
              {LABEL_STYLES.map((style) => (
                <button
                  key={style}
                  type="button"
                  className={`label-style ${config.label === style ? 'is-active' : ''}`}
                  aria-pressed={config.label === style}
                  onClick={() => onLabel({ label: style })}
                  data-testid={`label-${style}`}
                >
                  <strong>{LABEL_STYLE_LABELS[style]}</strong>
                  <small>{LABEL_HINTS[style]}</small>
                </button>
              ))}
            </div>

            <div className="field-label">
              Thread colour <span>{config.label === 'embroidered' ? '' : 'EMBROIDERY ONLY'}</span>
            </div>
            <div className="thread-row" role="group" aria-label="Thread colour">
              {THREADS.map((thread) => {
                const on = config.ink === thread.id
                const hex = thread.hex || inkColor('auto', config.parts.heel.color)
                return (
                  <button
                    key={thread.id}
                    type="button"
                    className={`thread ${on ? 'is-active' : ''} ${thread.id === 'auto' ? 'is-auto' : ''}`}
                    aria-pressed={on}
                    disabled={config.label !== 'embroidered'}
                    title={thread.name}
                    onClick={() => onLabel({ ink: thread.id })}
                    data-testid={`thread-${thread.id}`}
                  >
                    <span style={{ backgroundColor: hex }} />
                    {thread.id === 'auto' ? 'Auto' : <span className="sr-only">{thread.name}</span>}
                  </button>
                )
              })}
            </div>

            <div className="field-label">
              Heel tab colour <span>{PALETTE.find((p) => p.hex === config.parts.heel.color)?.name ?? 'Custom'}</span>
            </div>
            <div className="swatch-grid compact" role="group" aria-label="Heel tab colour">
              {PALETTE.map((p) => (
                <button
                  key={p.hex}
                  type="button"
                  aria-pressed={config.parts.heel.color === p.hex}
                  className={`swatch ${config.parts.heel.color === p.hex ? 'is-active' : ''}`}
                  style={{ backgroundColor: p.hex, color: relativeLuminance(p.hex) > 0.35 ? '#111' : '#fff' }}
                  title={p.name}
                  onClick={() => onUpdatePart('heel', { color: p.hex })}
                  data-testid={`heel-swatch-${p.name.toLowerCase().replace(/ /g, '-')}`}
                >
                  {config.parts.heel.color === p.hex && <Icon name="check" size={14} />}
                  <span className="sr-only">{p.name}</span>
                </button>
              ))}
            </div>
          </section>
        )}
        {section === 'save' && (
          <section className="save-panel">
            <span className="eyebrow">DESIGNED BY YOU. ONLY YOU.</span>
            <h3>
              One of a kind.
              <br />
              Ready to share.
            </h3>
            <p>
              Every colour. Every finish. Every detail.
              <br />
              Your entire design, saved in a link.
            </p>
            <div className="design-receipt">
              <header>
                <strong>COURT CLASSIC / 01</strong>
                <span>{config.text || 'YOUR EDITION'}</span>
              </header>
              {PART_IDS.map((part) => (
                <div key={part}>
                  <span className="receipt-swatch" style={{ backgroundColor: config.parts[part].color }} />
                  <span>{PART_LABELS[part]}</span>
                  <code>{config.parts[part].color.toUpperCase()}</code>
                  <span>{FINISH_LABELS[config.parts[part].finish]}</span>
                </div>
              ))}
            </div>
            <label className="field-label" htmlFor="share">
              Your share link
            </label>
            <div className="share-row">
              <input
                id="share"
                className="share-url"
                type="text"
                readOnly
                value={shareUrl}
                onFocus={(e) => e.currentTarget.select()}
                aria-label="Share URL"
                data-testid="share-url"
              />
              <button type="button" className="btn outline" onClick={onShare} data-testid="copy-link">
                Copy
              </button>
            </div>
            <a className="open-link" href={shareUrl} target="_blank" rel="noreferrer" data-testid="open-link">
              Open in a new tab <Icon name="arrow" size={16} />
            </a>
          </section>
        )}
      </div>
      <footer className="sidebar-footer">
        <button type="button" className="btn primary large" onClick={onDownload} data-testid="download-png">
          Download PNG <Icon name="download" size={19} />
        </button>
        <span className="footer-note">Your design. High resolution. No sign-up.</span>
      </footer>
    </aside>
  )
}
