import { useEffect, useRef } from 'react'
import { Icon } from './Icons'
import './Shortcuts.css'

const GROUPS: { title: string; items: [string[], string][] }[] = [
  {
    title: 'Canvas',
    items: [
      [['Drag'], 'Box select'],
      [['Space', 'Drag'], 'Pan'],
      [['Wheel'], 'Zoom around cursor'],
      [['+'], 'Zoom in'],
      [['−'], 'Zoom out'],
      [['Shift', '1'], 'Fit diagram to view'],
    ],
  },
  {
    title: 'Editing',
    items: [
      [['Drag port'], 'Connect nodes'],
      [['Double-click'], 'Edit label'],
      [['Enter'], 'Edit selected label'],
      [['Ctrl', 'D'], 'Duplicate selection'],
      [['Delete'], 'Delete selection'],
      [['Ctrl', 'A'], 'Select all'],
    ],
  },
  {
    title: 'General',
    items: [
      [['Ctrl', 'Z'], 'Undo'],
      [['Ctrl', 'Shift', 'Z'], 'Redo'],
      [['Ctrl', 'S'], 'Download JSON'],
      [['V'], 'Select tool'],
      [['H'], 'Pan tool'],
      [['Esc'], 'Clear selection'],
    ],
  },
]

export function Shortcuts({ onClose }: { onClose: () => void }) {
  const closeRef = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    closeRef.current?.focus()
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' || e.key === '?') {
        e.stopPropagation()
        e.preventDefault()
        onClose()
      }
    }
    window.addEventListener('keydown', onKey, true)
    return () => window.removeEventListener('keydown', onKey, true)
  }, [onClose])

  return (
    <div className="dialog-backdrop" onPointerDown={onClose}>
      <div
        className="dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="shortcuts-title"
        onPointerDown={(e) => e.stopPropagation()}
      >
        <header className="dialog-head">
          <h2 id="shortcuts-title">Keyboard shortcuts</h2>
          <button ref={closeRef} type="button" className="dialog-close" aria-label="Close" onClick={onClose}>
            <Icon name="close" size={16} />
          </button>
        </header>
        <div className="shortcut-groups">
          {GROUPS.map((group) => (
            <section key={group.title}>
              <h3>{group.title}</h3>
              <dl>
                {group.items.map(([keys, label]) => (
                  <div key={label} className="shortcut-row">
                    <dt>{label}</dt>
                    <dd>
                      {keys.map((k) => (
                        <kbd key={k}>{k}</kbd>
                      ))}
                    </dd>
                  </div>
                ))}
              </dl>
            </section>
          ))}
        </div>
      </div>
    </div>
  )
}
