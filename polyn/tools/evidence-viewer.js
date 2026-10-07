/** @typedef {{time: number, type: string, text: string, result: string | null}} RecordingEvent */
/** @typedef {{timestamp: string, steps: unknown[][]}} ActionBatch */

const video = document.querySelector('video')
const timeline = document.querySelector('#timeline')
const actionLog = document.querySelector('#action-log')
const dataElement = document.querySelector('#evidence-data')
const play = document.querySelector('#play')
const restart = document.querySelector('#restart')
const speed = document.querySelector('#speed')
const clock = document.querySelector('#clock')
const follow = document.querySelector('#follow')
const currentStep = document.querySelector('#current-step')
const recordedTab = document.querySelector('#recorded-tab')
const logTab = document.querySelector('#log-tab')
const description = document.querySelector('#panel-description')
const runStatus = document.querySelector('#run-status')
const mediaError = document.querySelector('#media-error')
const videoFile = document.querySelector('#video-file')
if (!(video instanceof HTMLVideoElement) || !(timeline instanceof HTMLOListElement) ||
    !(actionLog instanceof HTMLDivElement) || !dataElement || !play || !restart ||
    !(speed instanceof HTMLSelectElement) || !clock || !(follow instanceof HTMLInputElement) ||
    !currentStep || !recordedTab || !logTab || !description || !runStatus ||
    !(mediaError instanceof HTMLDivElement) || !(videoFile instanceof HTMLInputElement)) {
  throw new Error('Evidence viewer markup is incomplete.')
}
/** @type {{events: RecordingEvent[], batches: ActionBatch[]}} */
const evidence = JSON.parse(dataElement.textContent || '{}')
/** @param {number} seconds */
function timestamp(seconds) {
  if (!Number.isFinite(seconds)) return '--:--'
  return `${Math.floor(seconds / 60).toString().padStart(2, '0')}:${Math.floor(seconds % 60).toString().padStart(2, '0')}`
}
const assertions = evidence.events.filter((event) => event.type === 'assertion')
runStatus.textContent = `${assertions.filter((event) => event.result === 'passed').length} / ${assertions.length} assertions passed`
const labels = { setup: 'SETUP', test_start: 'TEST', assertion: 'ASSERTION', action: 'INPUT' }
const rows = evidence.events.map((event, index) => {
  const row = document.createElement('li')
  row.className = `event ${event.type}`
  const button = document.createElement('button')
  button.type = 'button'
  const meta = document.createElement('span')
  meta.className = 'event-meta'
  const badge = document.createElement('span')
  badge.className = 'badge'
  const label = Object.entries(labels).find(([type]) => type === event.type)?.[1] || 'EVENT'
  badge.textContent = `${String(index + 1).padStart(2, '0')}  ${event.result === 'passed' ? 'PASS' : label}`
  const time = document.createElement('time')
  time.textContent = timestamp(event.time)
  const text = document.createElement('span')
  text.className = 'event-text'
  text.textContent = event.text.replace(/^(TEST: |\[PASS\] )/, '')
  meta.append(badge, time)
  button.append(meta, text)
  button.addEventListener('click', () => {
    video.currentTime = event.time
    updatePlayback()
  })
  row.append(button)
  timeline.append(row)
  return { row, button }
})

for (const batch of evidence.batches) {
  const details = document.createElement('details')
  details.className = 'batch'
  const summary = document.createElement('summary')
  summary.textContent = `${batch.timestamp.replace('T', ' ').replace('Z', ' UTC')} · ${batch.steps.length} steps`
  const list = document.createElement('ol')
  for (const step of batch.steps) {
    const item = document.createElement('li')
    item.textContent = JSON.stringify(step)
    list.append(item)
  }
  details.append(summary, list)
  actionLog.append(details)
}

let active = -1
const updatePlayback = () => {
  clock.textContent = `${timestamp(video.currentTime)} / ${timestamp(video.duration)}`
  play.textContent = video.paused ? 'Play' : 'Pause'
  const index = evidence.events.findLastIndex((event) => event.time <= video.currentTime + 0.01)
  if (index === active) return
  active = index
  for (const [rowIndex, { row, button }] of rows.entries()) {
    row.classList.toggle('active', rowIndex === index)
    if (rowIndex === index) button.setAttribute('aria-current', 'step')
    else button.removeAttribute('aria-current')
  }
  currentStep.textContent = index < 0 ? 'Ready to play the full recorded session.' : evidence.events[index].text
  if (index >= 0 && follow.checked && !timeline.hidden) {
    const row = rows[index].row
    const offset = row.getBoundingClientRect().top - timeline.getBoundingClientRect().top
    if (offset < 0 || offset + row.offsetHeight > timeline.clientHeight) {
      timeline.scrollTo({ top: timeline.scrollTop + offset - 15, behavior: 'smooth' })
    }
  }
}
const togglePlayback = async () => {
  if (!video.paused) video.pause()
  else {
    try { await video.play() }
    catch { mediaError.hidden = false }
  }
}
play.addEventListener('click', togglePlayback)
restart.addEventListener('click', () => { video.currentTime = 0; updatePlayback() })
speed.addEventListener('change', () => { video.playbackRate = Number(speed.value) })
for (const event of ['timeupdate', 'loadedmetadata', 'play', 'pause', 'ended', 'seeked']) {
  video.addEventListener(event, updatePlayback)
}
video.addEventListener('error', () => { mediaError.hidden = false })
video.querySelector('source')?.addEventListener('error', () => { mediaError.hidden = false })
/** @param {boolean} log */
const showLog = (log) => {
  timeline.hidden = log
  actionLog.hidden = !log
  recordedTab.setAttribute('aria-pressed', String(!log))
  logTab.setAttribute('aria-pressed', String(log))
  follow.disabled = log
  description.textContent = log ? 'Original harness commands. Expand a batch to inspect.' : 'Select a timestamp to seek. Highlight follows playback.'
}
recordedTab.addEventListener('click', () => showLog(false))
logTab.addEventListener('click', () => showLog(true))
let objectUrl = ''
videoFile.addEventListener('change', () => {
  const file = videoFile.files?.[0]
  if (!file) return
  if (!file.name.toLowerCase().endsWith('.webm')) {
    videoFile.value = ''
    return
  }
  if (objectUrl) URL.revokeObjectURL(objectUrl)
  objectUrl = URL.createObjectURL(file)
  video.src = objectUrl
  mediaError.hidden = true
  video.load()
})
updatePlayback()
