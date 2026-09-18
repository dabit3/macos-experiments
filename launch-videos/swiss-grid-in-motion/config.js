// Editable parameters for "Swiss Grid in Motion" (dark).
// Times are seconds. The renderer samples at FPS and calls layout(t).
window.CONFIG = {
  fps: 30,
  duration: 28.0,
  width: 1920,
  height: 1080,

  // Brand tokens (dark mode, per BRIEF.md section 3)
  tokens: {
    bg: '#0B0B0C',
    shellBg: '#0E0E10',
    panel: '#17171A',
    panelRaised: '#1E1E22',
    hairline: 'rgba(245,245,245,0.08)',
    text: '#F5F5F5',
    muted: 'rgba(245,245,245,0.6)',
    faint: 'rgba(245,245,245,0.34)',
    accent: '#3A22FF',
    font: '-apple-system, "SF Pro Display", "SF Pro Text", Inter, system-ui, sans-serif',
  },

  // 12 column grid: margin 96, gutter 24, column 122 (96*2 + 12*122 + 11*24 = 1920)
  grid: { margin: 96, gutter: 24, columns: 12, top: 72 },

  // Headline / end card
  headline: ['macOS.', 'Now in Devin Cloud.'],
  headlineSize: 168,
  openLockupWidth: 480,
  endLockupWidth: 580,
  endUrl: 'devin.ai',
  endUrlSize: 44,

  // Composer scene
  composer: {
    prompt: 'Build Roomlight and run it on the iPad Simulator',
    charsPerSecond: 22,
    chipBefore: 'Ubuntu',
    chipAfter: 'macOS',
    menu: ['Ubuntu', 'macOS', 'Windows'],
    placeholder: 'Give Devin a task',
    width: 940,
  },

  // Session scene (captions are Devin status lines in the conversation column)
  session: {
    title: 'Roomlight for iPad',
    status: [
      { at: 10.6, text: 'Building Roomlight for the iPad Simulator' },
      { at: 12.2, text: 'Running in the Simulator' },
      { at: 16.8, text: 'Dragging the plant into place' },
      { at: 19.8, text: 'Switching to the 3D view' },
      { at: 22.6, text: 'Verified: the room renders in 3D', done: true },
    ],
  },

  // Footage: pre-extracted PNG frames of roomlight_ipad_landscape.mp4
  footage: {
    dir: 'frames/rl/',
    frameCount: 441,
    sourceIn: 11.0,        // seconds into the source clip at frame 0000
    startsAt: 11.5,        // video time when footage frame 0 shows (device appears here)
    width: 1536, height: 1152,
  },

  // Scene timeline (start times). Durations follow from the next start.
  scenes: {
    open: 0.0,
    composer: 3.4,
    session: 10.2,
    zoomIn: 13.4,     // push-in toward the iPad begins
    zoomHold: 15.0,
    zoomOut: 22.0,    // pull back for the verified result
    outro: 25.6,      // panels leave along grid lines
    end: 26.3,
  },
  zoom: { shellScale: 1.05, deviceScaleFrom: 0.86, composerScale: 1.33 },
};
