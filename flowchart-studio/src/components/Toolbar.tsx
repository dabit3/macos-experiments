import type { EdgeStyle } from '../types'
import { Icon, Logo } from './Icons'
import type { IconName } from './Icons'
import './Toolbar.css'

export type Tool = 'select' | 'pan'

interface ToolbarProps {
  tool: Tool
  onToolChange: (tool: Tool) => void
  edgeStyle: EdgeStyle
  onEdgeStyleChange: (style: EdgeStyle) => void
  snapToGrid: boolean
  onSnapChange: (snap: boolean) => void
  canUndo: boolean
  canRedo: boolean
  onUndo: () => void
  onRedo: () => void
  hasSelection: boolean
  onDuplicate: () => void
  onDelete: () => void
  onAutoLayout: () => void
  onImport: () => void
  onExportJSON: () => void
  onExportSVG: () => void
  onNew: () => void
}

function ToolButton({
  icon,
  label,
  title,
  active,
  disabled,
  primary,
  onClick,
  testId,
}: {
  icon: IconName
  label?: string
  title: string
  active?: boolean
  disabled?: boolean
  primary?: boolean
  onClick: () => void
  testId: string
}) {
  return (
    <button
      type="button"
      className={`tb-btn${active ? ' is-active' : ''}${label ? ' has-label' : ''}${primary ? ' is-primary' : ''}`}
      title={title}
      aria-label={title}
      aria-pressed={active}
      disabled={disabled}
      onClick={onClick}
      data-action={testId}
    >
      <Icon name={icon} />
      {label && <span>{label}</span>}
    </button>
  )
}

export function Toolbar(p: ToolbarProps) {
  return (
    <header className="toolbar">
      <div className="brand">
        <Logo size={30} />
        <span className="brand-text">
          <span className="brand-name">Flowchart Studio</span>
        </span>
      </div>

      <div className="tb-group" role="group" aria-label="Tools">
        <ToolButton icon="select" title="Select tool (V)" active={p.tool === 'select'} onClick={() => p.onToolChange('select')} testId="tool-select" />
        <ToolButton icon="hand" title="Pan tool (H) — or hold Space and drag" active={p.tool === 'pan'} onClick={() => p.onToolChange('pan')} testId="tool-pan" />
      </div>

      <div className="tb-group" role="group" aria-label="Edge style">
        <ToolButton icon="orthogonal" title="Orthogonal edges" active={p.edgeStyle === 'orthogonal'} onClick={() => p.onEdgeStyleChange('orthogonal')} testId="edges-orthogonal" />
        <ToolButton icon="straight" title="Straight edges" active={p.edgeStyle === 'straight'} onClick={() => p.onEdgeStyleChange('straight')} testId="edges-straight" />
      </div>

      <div className="tb-group" role="group" aria-label="Canvas">
        <ToolButton icon="grid" label="Snap" title={`Snap to grid: ${p.snapToGrid ? 'on' : 'off'}`} active={p.snapToGrid} onClick={() => p.onSnapChange(!p.snapToGrid)} testId="snap" />
        <ToolButton icon="layout" label="Auto layout" title="Auto layout (layered, top to bottom)" onClick={p.onAutoLayout} testId="auto-layout" />
      </div>

      <div className="tb-group" role="group" aria-label="Edit">
        <ToolButton icon="undo" title="Undo (Ctrl+Z)" disabled={!p.canUndo} onClick={p.onUndo} testId="undo" />
        <ToolButton icon="redo" title="Redo (Ctrl+Shift+Z)" disabled={!p.canRedo} onClick={p.onRedo} testId="redo" />
        <ToolButton icon="duplicate" title="Duplicate selection (Ctrl+D)" disabled={!p.hasSelection} onClick={p.onDuplicate} testId="duplicate" />
        <ToolButton icon="trash" title="Delete selection (Delete)" disabled={!p.hasSelection} onClick={p.onDelete} testId="delete" />
      </div>

      <div className="tb-spacer" />

      <span className="tb-saved" title="Changes are saved in this browser">
        <Icon name="check" size={14} />
        Saved locally
      </span>

      <div className="tb-group tb-group-plain" role="group" aria-label="File">
        <ToolButton icon="new" label="New" title="Clear the canvas" onClick={p.onNew} testId="new" />
        <ToolButton icon="import" label="Import JSON" title="Import a diagram from JSON" onClick={p.onImport} testId="import-json" />
        <ToolButton icon="json" label="Export JSON" title="Download the diagram as JSON" onClick={p.onExportJSON} testId="export-json" />
      </div>
      <ToolButton icon="svg" label="Export SVG" title="Download the diagram as SVG" primary onClick={p.onExportSVG} testId="export-svg" />
    </header>
  )
}
