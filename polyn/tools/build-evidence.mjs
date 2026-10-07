import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'

const [video, annotations, steps, report, poster, output] = process.argv.slice(2)
if (!video || !annotations || !steps || !report || !poster || !output) {
  throw new Error('Usage: node tools/build-evidence.mjs VIDEO.webm ANNOTATIONS.json STEPS.jsonl REPORT.md POSTER.png OUTPUT_DIRECTORY')
}
if (!video.toLowerCase().endsWith('.webm')) throw new Error('The recording must be WebM.')

const recording = JSON.parse(await readFile(annotations, 'utf8'))
const events = recording.annotations.map((event) => ({
  time: event.source_time_ms / 1000,
  type: event.type,
  text: event.display_text,
  result: event.test_result ?? null,
}))
if (!events.length || events.some((event) =>
  !Number.isFinite(event.time) || event.time < 0 ||
  typeof event.text !== 'string' ||
  !['setup', 'test_start', 'assertion', 'action'].includes(event.type)
)) throw new Error('Invalid recording annotations.')
events.sort((a, b) => a.time - b.time)
const batches = (await readFile(steps, 'utf8')).trim().split('\n').map((line) => JSON.parse(line))
if (batches.some((batch) => typeof batch.timestamp !== 'string' || !Array.isArray(batch.steps))) {
  throw new Error('Invalid programmatic action log.')
}

const data = JSON.stringify({ events, batches }).replaceAll('<', '\\u003c')
const template = await readFile(new URL('./evidence-viewer.html', import.meta.url), 'utf8')
const script = await readFile(new URL('./evidence-viewer.js', import.meta.url), 'utf8')
const html = template.replace('/* EVIDENCE_DATA */', () => data).replace('/* VIEWER_SCRIPT */', () => script)
const directory = resolve(output)
await mkdir(directory, { recursive: true })
await Promise.all([
  writeFile(resolve(directory, 'index.html'), html),
  copyFile(video, resolve(directory, 'recording.webm')),
  copyFile(report, resolve(directory, 'TEST_REPORT.md')),
  copyFile(poster, resolve(directory, 'poster.png')),
  copyFile(steps, resolve(directory, 'programmatic-steps.jsonl')),
  writeFile(resolve(directory, 'recording-events.json'), JSON.stringify(events, null, 2)),
  writeFile(resolve(directory, 'README.txt'), 'Open index.html in Chrome or Firefox. Keep all files together.\nThe recording is the full VP9 WebM. No internet, installation, or server is required.\nRecorded steps synchronize to source recording timestamps. The complete programmatic log has separate UTC batch timestamps; it includes earlier test runs.\n'),
])
console.log(`Evidence viewer generated: ${directory}`)
