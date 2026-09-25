import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ArrowDownToLine, ArrowLeft, ArrowRight, Box, Camera, ChevronDown, ChevronRight,
  CircleHelp, CloudSun, Copy, Eye, EyeOff, FileDown, FolderOpen, Focus, Image,
  Layers, Leaf, Lightbulb, Maximize, Minus, MousePointer2, Move, PanelLeft,
  Plus, Redo2, RefreshCw, RotateCcw, Save, Search, SlidersHorizontal, Sun, Trash2,
  Undo2, X, Check, Play, House, Grid2X2, Palette, TreePine, Armchair,
} from 'lucide-react';
import { addObject, commit, createProject, exportProject, MATERIALS, parseProject, redo, searchLibrary, STORAGE_KEY, undo, updateObject } from './model';
import type { Ambience, AssetKind, CameraShot, History, Project, SceneObject, Vec3 } from './model';
import { createLibraryPreview, SceneEngine } from './scene';

function initialState(): History {
  try {
    return { past: [], present: parseProject(localStorage.getItem(STORAGE_KEY) ?? '') ?? createProject(), future: [] };
  } catch { return { past: [], present: createProject(), future: [] }; }
}
function download(content: string, filename: string, type: string) {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const anchor = document.createElement('a');
  anchor.href = url; anchor.download = filename; anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function AssetPreview({ kind }: { kind: AssetKind }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => { if (ref.current) createLibraryPreview(kind, ref.current); }, [kind]);
  return <div className="asset-preview" ref={ref} />;
}
function ShotPreview({ engine, shot }: { engine: SceneEngine | null; shot: CameraShot }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const element = ref.current;
    if (!engine || !element) return;
    let timer: number | undefined;
    const observer = new IntersectionObserver(entries => {
      clearTimeout(timer);
      if (entries.some(entry => entry.isIntersecting)) timer = window.setTimeout(() => {
        element.replaceChildren(engine.thumbnail(shot));
        observer.disconnect();
      }, 350);
    });
    observer.observe(element);
    return () => { observer.disconnect(); clearTimeout(timer); };
  }, [engine, shot.id, shot.position, shot.target, shot.ambience]);
  return <div className="shot-preview" ref={ref} />;
}
function NumberField({ label, value, min, max, step = 0.1, onCommit }: { label: string; value: number; min: number; max: number; step?: number; onCommit: (value: number) => void }) {
  const [draft, setDraft] = useState(String(value));
  useEffect(() => setDraft(String(value)), [value]);
  function submit() {
    const next = Number(draft);
    if (draft.trim() && Number.isFinite(next) && next >= min && next <= max) onCommit(next);
    else setDraft(String(value));
  }
  return <input aria-label={label} type="number" step={step} min={min} max={max} value={draft}
    onChange={event => setDraft(event.target.value)} onBlur={submit}
    onKeyDown={event => { if (event.key === 'Enter') event.currentTarget.blur(); }} />;
}
function RangeField({ id, label, value, min, max, step = 1, onCommit }: { id: string; label: string; value: number; min: number; max: number; step?: number; onCommit: (value: number) => void }) {
  const input = useRef<HTMLInputElement>(null);
  const timer = useRef<number | undefined>(undefined);
  useEffect(() => {
    clearTimeout(timer.current);
    if (input.current) input.current.value = String(value);
  }, [value]);
  useEffect(() => () => clearTimeout(timer.current), []);
  function submit() {
    clearTimeout(timer.current);
    if (input.current) onCommit(Number(input.current.value));
  }
  return <input ref={input} id={id} className="range" aria-label={label} type="range"
    min={min} max={max} step={step} defaultValue={value}
    onChange={() => { clearTimeout(timer.current); timer.current = window.setTimeout(submit, 200); }}
    onPointerUp={submit} onBlur={submit} />;
}
const clock = (value: number) => `${String(Math.floor(value)).padStart(2, '0')}:${String(Math.round((value % 1) * 60)).padStart(2, '0')}`;
const ObjectIcon = ({ kind }: { kind: AssetKind }) => ['pine', 'maple', 'birch', 'fern'].includes(kind) ? <TreePine /> : kind === 'chair' || kind === 'bench' ? <Armchair /> : kind === 'lamp' ? <Lightbulb /> : <Box />;

export default function App() {
  const [history, setHistory] = useState<History>(initialState);
  const project = history.present;
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selected = project.objects.find(object => object.id === selectedId);
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState('All');
  const [sceneQuery, setSceneQuery] = useState('');
  const [dock, setDock] = useState<'Media' | 'Materials'>('Media');
  const [leftOpen, setLeftOpen] = useState(true);
  const [rightOpen, setRightOpen] = useState(true);
  const [dockOpen, setDockOpen] = useState(true);
  const [presenting, setPresenting] = useState(false);
  const [activeShot, setActiveShot] = useState('hero');
  const [menu, setMenu] = useState<'file' | 'edit' | 'help' | null>(null);
  const [status, setStatus] = useState('All changes saved');
  const [error, setError] = useState('');
  const [engine, setEngine] = useState<SceneEngine | null>(null);
  const viewport = useRef<HTMLDivElement>(null);
  const engineRef = useRef<SceneEngine | null>(null);
  const importRef = useRef<HTMLInputElement>(null);
  const choose = useCallback((id: string | null) => { setSelectedId(id); setRightOpen(true); }, []);

  useEffect(() => {
    if (!viewport.current) return;
    try {
      const scene = new SceneEngine(viewport.current, choose);
      engineRef.current = scene; setEngine(scene);
      return () => { scene.dispose(); engineRef.current = null; };
    } catch (e) { setError(`WebGL could not start: ${e instanceof Error ? e.message : 'Unknown error'}. Please enable hardware acceleration.`); }
  }, [choose]);
  useEffect(() => { engineRef.current?.update(project, selectedId); }, [project, selectedId, engine]);
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, exportProject(project)); setStatus('All changes saved');
    } catch { setStatus('Storage unavailable — export your project to keep changes'); }
  }, [project]);
  const change = useCallback((next: Project | ((current: Project) => Project)) => {
    setHistory(previous => commit(previous, typeof next === 'function' ? next(previous.present) : next));
  }, []);
  const remove = useCallback(() => {
    if (selectedId) change(p => ({ ...p, objects: p.objects.filter(o => o.id !== selectedId) }));
    setSelectedId(null);
  }, [selectedId, change]);
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') { setPresenting(false); setMenu(null); }
      if (event.target instanceof HTMLElement && ['INPUT', 'TEXTAREA', 'SELECT'].includes(event.target.tagName)) return;
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') {
        event.preventDefault(); setHistory(event.shiftKey ? redo : undo);
      } else if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') {
        event.preventDefault();
        download(exportProject(project), 'forest-house.nuvio.json', 'application/json');
      } else if (event.key.toLowerCase() === 'f') engineRef.current?.focus();
      else if (event.key === 'Delete') remove();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [project, remove]);
  function patchSelected(patch: Partial<SceneObject>) {
    if (selectedId) change(p => updateObject(p, selectedId, patch));
  }
  function ambience(patch: Partial<Ambience>) { change(p => ({ ...p, ambience: { ...p.ambience, ...patch } })); }
  function place(kind: AssetKind) {
    if (project.objects.length >= 150) { setStatus('Object limit reached (150). Delete an object to place another.'); return; }
    const id = crypto.randomUUID();
    change(p => addObject(p, kind, id)); choose(id);
  }
  function openShot(shot: CameraShot) {
    engine?.setCamera(shot); setActiveShot(shot.id);
    change(p => ({ ...p, ambience: { ...shot.ambience } }));
  }
  function saveShot() {
    if (!engine || project.shots.length >= 20) return;
    const id = crypto.randomUUID();
    const shot: CameraShot = { id, name: `${String(project.shots.length + 1).padStart(2, '0')} · New image`, ...engine.getCamera(), ambience: { ...project.ambience } };
    change(p => ({ ...p, shots: [...p.shots, shot] })); setActiveShot(id);
  }
  async function exportImage() {
    if (!engine) return;
    try {
      const url = URL.createObjectURL(await engine.capture());
      const anchor = document.createElement('a');
      anchor.download = 'nuvio-forest-house.png';
      anchor.href = url; anchor.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setStatus('PNG image exported');
    } catch { setError('Could not export this view. Try again once the scene finishes rendering.'); }
  }
  function duplicate() {
    if (!selected || project.objects.length >= 150) return;
    const id = crypto.randomUUID();
    const position: Vec3 = [selected.position[0] + 1.5, selected.position[1], selected.position[2] + 1.5];
    change(p => ({ ...p, objects: [...p.objects, { ...selected, id, name: `${selected.name.slice(0, 90)} copy`, position }] }));
    choose(id);
  }
  const assets = searchLibrary(query, category);
  const shownObjects = project.objects.filter(object => object.name.toLowerCase().includes(sceneQuery.toLowerCase()));

  return <div className={`app ${presenting ? 'presentation' : ''}`} style={{ '--left-width': leftOpen ? '252px' : '0px', '--right-width': rightOpen ? '292px' : '0px', '--dock-height': dockOpen ? '190px' : '0px' } as React.CSSProperties}>
    <header className="topbar">
      <div className="brand"><span className="brand-mark">n</span><b>nuvio</b></div>
      <div className="menu-wrap">
        <button onClick={() => setMenu(menu === 'file' ? null : 'file')}>File</button>
        <button onClick={() => setMenu(menu === 'edit' ? null : 'edit')}>Edit</button>
        <button onClick={() => setMenu(menu === 'help' ? null : 'help')}>Help</button>
        {menu === 'file' && <div className="dropdown">
          <button onClick={() => { download(exportProject(project), 'forest-house.nuvio.json', 'application/json'); setMenu(null); }}><Save />Save project <kbd>Ctrl S</kbd></button>
          <button onClick={() => { importRef.current?.click(); setMenu(null); }}><FolderOpen />Open project…</button>
          <button onClick={() => { exportImage(); setMenu(null); }}><Image />Export image</button>
          <hr />
          <button onClick={() => { change(createProject()); choose(null); engine?.setCamera(createProject().shots[0]); setMenu(null); }}><RotateCcw />Reset demo <span>Undoable</span></button>
        </div>}
        {menu === 'edit' && <div className="dropdown">
          <button disabled={!history.past.length} onClick={() => setHistory(undo)}><Undo2 />Undo <kbd>Ctrl Z</kbd></button>
          <button disabled={!history.future.length} onClick={() => setHistory(redo)}><Redo2 />Redo <kbd>Ctrl Shift Z</kbd></button>
          <button disabled={!selected} onClick={() => { duplicate(); setMenu(null); }}><Copy />Duplicate selection</button>
          <button disabled={!selected} onClick={() => { remove(); setMenu(null); }}><Trash2 />Delete selection</button>
        </div>}
      </div>
      <div className="project-title">{project.name}<span> / </span> Forest retreat.nuvio <span className="saved-dot" /></div>
      <span className="version">2025.1 · Local workspace</span>
    </header>
    <div className="toolbar">
      <button title="Restore arrival view" onClick={() => openShot(project.shots[0] ?? createProject().shots[0])}><House /></button>
      <span className="toolbar-divider" />
      <span className="project-breadcrumb"><FolderOpen /> Projects <ChevronRight /> <b>Forest House</b></span>
      <div className="center-tools">
        <button title="Undo (Ctrl+Z)" disabled={!history.past.length} onClick={() => setHistory(undo)}><Undo2 /></button>
        <button title="Redo (Ctrl+Shift+Z)" disabled={!history.future.length} onClick={() => setHistory(redo)}><Redo2 /></button>
        <span className="toolbar-divider" />
        <button className="active" title="Select objects in the viewport" onClick={() => choose(null)}><MousePointer2 /></button>
        <button title="Edit selected object transforms" disabled={!selected} onClick={() => setRightOpen(true)}><Move /></button>
        <button title="Focus selection (F)" disabled={!selected} onClick={() => engine?.focus()}><Focus /></button>
        <span className="toolbar-divider" />
        <button title="Environment settings" onClick={() => choose(null)}><Sun /></button>
      </div>
      <button className="present-button" onClick={() => setPresenting(true)}><Play /> Present</button>
      <button className="export-button" onClick={exportImage}><ArrowDownToLine /> Export image</button>
    </div>
    <aside className="library">
      <div className="panel-title"><span><PanelLeft /> Library</span><button title="Hide library" onClick={() => setLeftOpen(false)}><Minus /></button></div>
      <label className="search"><Search /><input placeholder="Search library" aria-label="Search library" value={query} onChange={event => setQuery(event.target.value)} /><span>⌕</span></label>
      <div className="library-nav"><button onClick={() => { setCategory('All'); setQuery(''); }}><Layers /> Library</button><ChevronRight /><span>{category === 'All' ? 'Local assets' : category}</span></div>
      <div className="category-grid">
        {[['All', Grid2X2], ['Vegetation', TreePine], ['Objects', Armchair], ['Lights', Lightbulb]].map(([name, Icon]) => {
          const CategoryIcon = Icon as typeof Grid2X2;
          return <button key={String(name)} className={category === name ? 'selected' : ''} onClick={() => setCategory(String(name))}><CategoryIcon /><span>{String(name)}</span></button>;
        })}
      </div>
      <div className="section-label"><span>{query ? 'Search results' : category === 'All' ? 'Curated for your scene' : category}</span><small>{assets.length} assets</small></div>
      <div className="assets">
        {assets.map(asset => <button className="asset" key={asset.kind} onClick={() => place(asset.kind)} disabled={project.objects.length >= 150} title={project.objects.length >= 150 ? 'Object limit reached (150). Delete an object to place another.' : `Place ${asset.name} — ${asset.detail}`}>
          <div className="asset-image"><AssetPreview kind={asset.kind} /><span className="asset-add"><Plus /></span><span className="local-badge"><Check /></span></div>
          <span>{asset.name}</span><small>{asset.detail}</small>
        </button>)}
        {!assets.length && <div className="empty-state"><Search /><b>No matching assets</b><p>Try “tree”, “oak”, or “light”.</p><button onClick={() => { setQuery(''); setCategory('All'); }}>Clear filters</button></div>}
      </div>
      <div className="library-note"><span className="green-dot" /><span>{project.objects.length >= 150 ? '150 object limit reached' : 'Local library'} <small>{project.objects.length >= 150 ? 'Delete an object to place another' : 'Click an asset to place it in your scene'}</small></span></div>
    </aside>
    <main className="viewport-shell">
      <div ref={viewport} className="viewport" />
      <div className="viewport-heading"><span className="live-dot" /> Real time <span className="badge" title={engine?.performanceMode ? 'Reduced render resolution and forest detail for software WebGL' : 'Hardware WebGL renderer'}>{engine?.performanceMode ? 'Performance' : 'Standard'}</span></div>
      <div className="viewport-actions"><button title="Frame whole project" onClick={() => engine?.setCamera(createProject().shots[0])}><Focus /></button><button title="Presentation mode" onClick={() => setPresenting(true)}><Maximize /></button></div>
      <div className="scene-caption"><span>THE FOREST HOUSE</span><h1>A quieter kind of architecture.</h1><p>Nordic retreat · 59° 19′ N, 18° 04′ E</p></div>
      <div className="view-bottom"><span><MousePointer2 /> Drag to orbit <i /> Scroll to zoom <i /> F to focus</span><div className="compass"><span>N</span><ArrowRight /></div></div>
      {selected && <div className="selection-label"><Box />{selected.name}<button title="Deselect" onClick={() => choose(null)}><X /></button></div>}
      {error && <div className="error-banner" role="alert">{error}<button onClick={() => setError('')}><X /></button></div>}
    </main>
    <aside className="right-panel">
      <div className="panel-title"><span><Layers /> Scene</span><span className="subtle">{project.objects.length} objects</span></div>
      <label className="search"><Search /><input placeholder="Search scene" aria-label="Search scene" value={sceneQuery} onChange={event => setSceneQuery(event.target.value)} /></label>
      <div className="scene-tree">
        <button className={`tree-row ambience-row ${!selected ? 'selected' : ''}`} onClick={() => choose(null)}><CloudSun /><span>Ambience</span></button>
        <div className="tree-folder"><ChevronDown /><FolderOpen /> Forest House <span>●</span></div>
        {shownObjects.map(object => <div className={`tree-row ${selectedId === object.id ? 'selected' : ''} ${!object.visible ? 'muted' : ''}`} key={object.id}>
          <button className="object-select" onClick={() => choose(object.id)}><ObjectIcon kind={object.kind} /><span>{object.name}</span></button>
          <button title={`${object.visible ? 'Hide' : 'Show'} ${object.name}`} onClick={() => change(p => updateObject(p, object.id, { visible: !object.visible }))}>{object.visible ? <Eye /> : <EyeOff />}</button>
        </div>)}
        {!shownObjects.length && <p className="scene-empty">No objects match your search.</p>}
      </div>
      <div className="properties-title"><span>{selected ? <Box /> : <CloudSun />}{selected ? 'Object properties' : 'Ambience'}</span><SlidersHorizontal /></div>
      <div className="properties">
        {selected ? <>
          <div className="object-heading"><ObjectIcon kind={selected.kind} /><div><b>{selected.name}</b><small>{selected.kind} · Local object</small></div></div>
          <label className="field">Name<input aria-label="Object name" maxLength={100} value={selected.name} onChange={event => { if (event.target.value.trim()) patchSelected({ name: event.target.value }); }} /></label>
          <div className="property-section"><h3><ChevronDown />Transform <button title="Reset selected transform" onClick={() => patchSelected({ position: [0, 0, 0], rotation: 0, scale: 1 })}><RotateCcw /></button></h3>
            <span className="field-label">Position <small>m</small></span>
            <div className="xyz">{(['X', 'Y', 'Z'] as const).map((axis, i) => <label key={`${selected.id}-${axis}`}><span className={`axis-${axis}`}>{axis}</span><NumberField label={`Position ${axis}`} min={-100} max={100} value={selected.position[i]} onCommit={value => {
              const position: Vec3 = [...selected.position]; position[i] = value; patchSelected({ position });
            }} /></label>)}</div>
            <div className="two-fields"><label>Rotation <div><NumberField key={`${selected.id}-rotation`} label="Rotation" min={-360} max={360} step={1} value={selected.rotation} onCommit={value => patchSelected({ rotation: value })} /><span>°</span></div></label><label>Scale<div><NumberField key={`${selected.id}-scale`} label="Scale" min={0.1} max={5} value={selected.scale} onCommit={value => patchSelected({ scale: value })} /><span>×</span></div></label></div>
          </div>
          <div className="property-section"><h3><ChevronDown />Material</h3><div className="selected-material"><span style={{ background: MATERIALS.find(m => m.id === selected.material)?.color }} /><div>{MATERIALS.find(m => m.id === selected.material)?.name}<small>Surface finish</small></div></div>
            <div className="small-swatches">{MATERIALS.map(material => <button key={material.id} title={`Apply ${material.name}`} aria-label={`Apply ${material.name}`} className={selected.material === material.id ? 'selected' : ''} style={{ background: material.color }} onClick={() => patchSelected({ material: material.id })}>{selected.material === material.id && <Check />}</button>)}</div>
          </div>
          <div className="object-actions"><button onClick={duplicate} disabled={project.objects.length >= 150}><Copy />Duplicate</button><button onClick={remove}><Trash2 />Delete</button></div>
          <button className="wide-button" onClick={() => engine?.focus()}><Focus />Frame selected object <kbd>F</kbd></button>
        </> : <>
          <div className="property-tabs"><button className="selected"><Sun />Env</button><button onClick={() => { setDock('Media'); setDockOpen(true); }}><Camera />Camera</button><button title="Standard real-time renderer active" disabled><Box />Render</button><button title="Post-processing effects are outside this V1" disabled><SlidersHorizontal />FX</button></div>
          <div className="sky-heading"><span><CloudSun /> Environment</span><span className="tiny-badge">DYNAMIC SKY</span></div>
          <div className="sky-preview"><Sun /><span>{project.ambience.time < 15 ? 'Daylight' : project.ambience.time > 19 ? 'Blue hour' : 'Golden hour'}<small>Nordic summer sky</small></span></div>
          <div className="property-section"><h3><ChevronDown />Sun</h3>
            <label className="range-label" htmlFor="time">Time of day <b>{clock(project.ambience.time)}</b></label>
            <RangeField id="time" label="Time of day" min={6} max={21} step={0.25} value={project.ambience.time} onCommit={time => ambience({ time })} />
            <div className="range-ends"><span>06:00</span><Sun /><span>21:00</span></div>
          </div>
          <div className="property-section"><h3><ChevronDown />Weather & season</h3>
            <label className="field">Weather<select aria-label="Weather" value={project.ambience.weather} onChange={event => ambience({ weather: event.target.value as Ambience['weather'] })}><option>Clear</option><option>Overcast</option><option>Mist</option></select></label>
            <span className="field-label">Season</span><div className="segmented">{(['Summer', 'Autumn', 'Winter'] as const).map(season => <button key={season} className={project.ambience.season === season ? 'selected' : ''} onClick={() => ambience({ season })}>{season}</button>)}</div>
          </div>
          <div className="property-section"><h3><ChevronDown />Atmosphere</h3><label className="range-label" htmlFor="fog">Haze <b>{project.ambience.fog}%</b></label><RangeField id="fog" label="Haze" min={0} max={100} value={project.ambience.fog} onCommit={fog => ambience({ fog })} /></div>
        </>}
      </div>
    </aside>
    <section className="bottom-dock">
      <div className="dock-header"><div className="dock-tabs"><button className={dock === 'Media' ? 'selected' : ''} onClick={() => setDock('Media')}><Image />Media</button><button className={dock === 'Materials' ? 'selected' : ''} onClick={() => setDock('Materials')}><Palette />Materials</button></div><div className="dock-header-right"><span>{dock === 'Media' ? `${project.shots.length} images` : '6 local materials'}</span>{dock === 'Media' && <button title="Save current camera as image" disabled={project.shots.length >= 20} onClick={saveShot}><Plus />Create image</button>}<button title="Collapse dock" onClick={() => setDockOpen(false)}><ChevronDown /></button></div></div>
      {dock === 'Media' ? <div className="media-strip">
        {project.shots.map(shot => <div key={shot.id} className={`shot-card ${shot.id === activeShot ? 'selected' : ''}`}>
          <button className="shot-image" title={`Open ${shot.name}`} onClick={() => openShot(shot)}><ShotPreview shot={shot} engine={engine} /><span className="shot-number"><Image /> Image</span>{shot.id === activeShot && <span className="shot-selected"><Check /></span>}</button>
          <div className="shot-caption"><input aria-label={`Rename ${shot.name}`} value={shot.name} maxLength={100} onChange={event => { if (event.target.value.trim()) change(p => ({ ...p, shots: p.shots.map(s => s.id === shot.id ? { ...s, name: event.target.value } : s) })); }} /><button title={`Update ${shot.name} from current view`} onClick={() => { if (engine) change(p => ({ ...p, shots: p.shots.map(s => s.id === shot.id ? { ...s, ...engine.getCamera(), ambience: { ...p.ambience } } : s) })); }}><RefreshCw /></button><button title={`Delete ${shot.name}`} onClick={() => change(p => ({ ...p, shots: p.shots.filter(s => s.id !== shot.id) }))}><Trash2 /></button></div>
        </div>)}
        <button className="create-shot" onClick={saveShot} disabled={project.shots.length >= 20}><Plus /><span>Create image</span><small>Save current view</small></button>
      </div> : <div className="material-strip">{MATERIALS.map(material => <button disabled={!selected} key={material.id} title={selected ? `Apply ${material.name}` : 'Select an object to apply a material'} onClick={() => patchSelected({ material: material.id })}><div className={`material-sphere ${material.id}`} style={{ backgroundColor: material.color }} /><span>{material.name}</span></button>)}{!selected && <p>Select an object to apply a material.</p>}</div>}
    </section>
    <footer className="footer">
      <div className="footer-left"><button className={leftOpen ? 'active' : ''} onClick={() => setLeftOpen(!leftOpen)}><PanelLeft />Library</button><span className="local-status"><span className="green-dot" />Local</span></div>
      <div className="footer-center"><button onClick={() => importRef.current?.click()}><FileDown />Import</button><button className={dockOpen && dock === 'Materials' ? 'active' : ''} onClick={() => { setDock('Materials'); setDockOpen(true); }}><Palette />Materials</button><button onClick={() => { setLeftOpen(true); setCategory('Vegetation'); }}><Leaf />Populate</button><button className={dockOpen && dock === 'Media' ? 'active' : ''} onClick={() => { setDock('Media'); setDockOpen(!dockOpen || dock !== 'Media'); }}><Image />Media</button><button onClick={exportImage}><ArrowDownToLine />Export</button></div>
      <div className="footer-right"><button className={rightOpen ? 'active' : ''} onClick={() => setRightOpen(!rightOpen)}><Layers />Scene</button><button className={rightOpen ? 'active' : ''} onClick={() => { choose(null); setRightOpen(!rightOpen); }}><SlidersHorizontal />Properties</button></div>
    </footer>
    <div className="statusbar"><span><Check />{status}</span><span>WebGL 2 <i />Procedural scene <i />Nuvio V1</span></div>
    {presenting && <div className="presentation-controls"><span><b>nuvio</b> / {project.name}</span><button title="Previous camera" onClick={() => { const i = project.shots.findIndex(s => s.id === activeShot); const shot = project.shots[(i - 1 + project.shots.length) % project.shots.length]; if (shot) openShot(shot); }}><ArrowLeft /></button><button title="Next camera" onClick={() => { const i = project.shots.findIndex(s => s.id === activeShot); const shot = project.shots[(i + 1) % project.shots.length]; if (shot) openShot(shot); }}><ArrowRight /></button><button onClick={exportImage}><Camera />Save image</button><button onClick={() => setPresenting(false)}><X />Exit <kbd>Esc</kbd></button></div>}
    {menu === 'help' && <div className="modal-backdrop" onClick={() => setMenu(null)}><section className="help-modal" role="dialog" aria-label="Nuvio controls" onClick={event => event.stopPropagation()}><button className="modal-close" title="Close help" onClick={() => setMenu(null)}><X /></button><CircleHelp /><h2>A little space to create.</h2><p>Explore the retreat, make it yours, and save a point of view.</p><dl><dt>Orbit / zoom</dt><dd>Drag / mouse wheel</dd><dt>Pan</dt><dd>Right-drag</dd><dt>Select</dt><dd>Click geometry or a scene row</dd><dt>Frame selection</dt><dd>F</dd><dt>Undo / redo</dt><dd>Ctrl Z / Ctrl Shift Z</dd><dt>Save project</dt><dd>Ctrl S</dd></dl><p className="subtle">Local browser V1 inspired by Twinmotion 2025.1. Original procedural assets. No Epic affiliation. Native engine, cloud, VR and CAD imports are outside this demo.</p><button className="wide-button" onClick={() => setMenu(null)}>Back to the forest</button></section></div>}
    <input ref={importRef} className="hidden" type="file" accept=".json" aria-label="Import Nuvio project" onChange={async event => {
      const file = event.target.files?.[0]; if (!file) return;
      if (file.size > 500_000) { setError('Project is too large. Maximum size is 500 KB.'); event.target.value = ''; return; }
      const parsed = parseProject(await file.text());
      if (parsed) { setError(''); change(parsed); choose(null); if (parsed.shots[0]) { engine?.setCamera(parsed.shots[0]); setActiveShot(parsed.shots[0].id); } }
      else setError('This is not a valid Nuvio V1 project. The current scene was kept.');
      event.target.value = '';
    }} />
  </div>;
}
