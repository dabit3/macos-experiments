import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { after, before, test } from 'node:test'

let fixture
const originalEvents = [
  { source_time_ms: 325371, edited_time_s: 11.011, type: 'assertion', test_result: 'passed', display_text: '[PASS] Reload retains exact edits.' },
  { source_time_ms: 11918, edited_time_s: 2.259, type: 'test_start', display_text: 'TEST: </script><script>alert("untrusted")</script>' },
]
const batch = { timestamp: '2026-09-15T16:14:02.000Z', steps: [['field', 'Location X', '4']] }
before(async () => {
  await mkdir('.devin', { recursive: true })
  fixture = await mkdtemp(resolve('.devin/evidence-builder-test-'))
  await Promise.all([
    writeFile(resolve(fixture, 'video.webm'), 'test-video-bytes'),
    writeFile(resolve(fixture, 'poster.png'), 'test-poster-bytes'),
    writeFile(resolve(fixture, 'report.md'), '# Original report'),
    writeFile(resolve(fixture, 'events.json'), JSON.stringify({ annotations: originalEvents, video_url: 'ignored-internal.mp4' })),
    writeFile(resolve(fixture, 'steps.jsonl'), `${JSON.stringify(batch)}\n`),
  ])
})
after(async () => { if (fixture) await rm(fixture, { recursive: true, force: true }) })

function build(video = 'video.webm', events = 'events.json') {
  return execFileSync(process.execPath, [
    'tools/build-evidence.mjs',
    ...[video, events, 'steps.jsonl', 'report.md', 'poster.png', 'bundle'].map((path) => resolve(fixture, path)),
  ], { encoding: 'utf8', stdio: 'pipe' })
}

test('keeps original video bytes, exact source timestamps and raw programmatic steps', async () => {
  build()
  const output = resolve(fixture, 'bundle')
  const events = JSON.parse(await readFile(resolve(output, 'recording-events.json'), 'utf8'))
  assert.deepEqual(events.map((event) => event.time), [11.918, 325.371])
  assert.equal(await readFile(resolve(output, 'recording.webm'), 'utf8'), 'test-video-bytes')
  assert.equal(await readFile(resolve(output, 'programmatic-steps.jsonl'), 'utf8'), `${JSON.stringify(batch)}\n`)
  assert.equal(await readFile(resolve(output, 'TEST_REPORT.md'), 'utf8'), '# Original report')
})

test('safely embeds annotation text and omits original internal recording paths', async () => {
  build()
  const html = await readFile(resolve(fixture, 'bundle/index.html'), 'utf8')
  assert.ok(!html.includes('</script><script>alert'))
  assert.ok(html.includes('\\u003c/script>'))
  assert.ok(!html.includes('ignored-internal.mp4'))
  assert.ok(!html.includes('/* EVIDENCE_DATA */'))
  assert.ok(!html.includes('/* VIEWER_SCRIPT */'))
  assert.ok(html.includes('src="recording.webm"'))
  assert.ok(html.includes('time <= video.currentTime'))
})

test('rejects MP4 input', () => {
  assert.throws(() => build('video.mp4'), /The recording must be WebM/)
})

test('rejects annotations without a valid original recording timestamp', async () => {
  await writeFile(resolve(fixture, 'invalid-events.json'), JSON.stringify({
    annotations: [{ type: 'test_start', display_text: 'Missing source time', edited_time_s: 1 }],
  }))
  assert.throws(() => build('video.webm', 'invalid-events.json'), /Invalid recording annotations/)
})
