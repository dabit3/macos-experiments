// Native input + read-only browser observations + uncut desktop capture.
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'
import { spawn, execFileSync } from 'node:child_process'
import { setTimeout as delay } from 'node:timers/promises'

const appRoot = fileURLToPath(new URL('../', import.meta.url))
const evidence = path.join(appRoot, '.devin/clone-this/draev/evidence')
const run = (cmd, args) => execFileSync(cmd, args, { encoding: 'utf8' })
export class ComputerTest {
  static async open(sourceURL) {
    const t = new ComputerTest()
    fs.mkdirSync(evidence, { recursive: true })
    t.out = fs.mkdtempSync(path.join(evidence, 'computer-use-'))
    t.source = fileURLToPath(sourceURL)
    fs.copyFileSync(t.source, path.join(t.out, 'executed-script.mjs'))
    t.errors = []; t.events = []; t.index = 0; t.pending = new Map()
    t.sequence = 0; t.failed = false
    const endpoint = process.env.CU_CDP || 'http://localhost:29229'
    const url = process.env.CU_URL || 'http://localhost:4173/'
    const tabs = await (await fetch(`${endpoint}/json/list`)).json()
    const tab = tabs.find(p => p.type === 'page' && p.url === url)
    assert.ok(tab, `Open ${url} in Chrome with remote debugging first`)
    t.ws = new WebSocket(tab.webSocketDebuggerUrl)
    await new Promise((resolve, reject) => {
      t.ws.addEventListener('open', resolve, { once: true })
      t.ws.addEventListener('error', reject, { once: true })
    })
    t.ws.addEventListener('message', ({ data }) => {
      const m = JSON.parse(data)
      if (m.id) { t.pending.get(m.id)?.(m); t.pending.delete(m.id) }
      if (m.method === 'Runtime.exceptionThrown' ||
          (m.method === 'Runtime.consoleAPICalled' &&
            ['error', 'assert'].includes(m.params.type)) ||
          m.method === 'Network.loadingFailed') t.errors.push(m)
    })
    await t.send('Runtime.enable'); await t.send('Network.enable')
    await t.send('Browser.setDownloadBehavior',
      { behavior: 'allow', downloadPath: t.out })
    const dims = await t.read(
      '[innerWidth,innerHeight,screen.width,screen.height,devicePixelRatio]')
    assert.deepEqual(dims, [1920,1080,1920,1080,1],
      'Use fullscreen Chrome at 1920x1080, 100% browser zoom')
    run('wmctrl', ['-r', ':ACTIVE:', '-b', 'add,maximized_vert,maximized_horz'])
    // Foreground page already fullscreen: CDP bounds are physical coordinates.
    // ffmpeg progress gives frame-one readiness; monotonic timestamps start here.
    t.video = spawn('ffmpeg', ['-y', '-hide_banner', '-loglevel', 'error',
      '-f', 'x11grab', '-video_size', '1920x1080', '-framerate', '24',
      '-draw_mouse', '1', '-i', `${process.env.DISPLAY || ':0'}.0`,
      '-c:v', 'ffv1', '-threads', '2', '-progress', 'pipe:1',
      path.join(t.out, 'desktop.mkv')], { stdio: ['pipe','pipe','pipe'] })
    t.captureLog = ''
    t.video.stderr.on('data', x => { t.captureLog += x })
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(Error('Capture did not start')), 15000)
      t.video.once('error', reject)
      t.video.once('exit', code => {
        if (code) reject(Error(`Capture failed: ${t.captureLog}`))
      })
      t.video.stdout.once('data', chunk => {
        const elapsed = Number(String(chunk).match(/out_time_us=(\d+)/)?.[1] || 0)
        clearTimeout(timer); t.epoch = performance.now() - elapsed/1000; resolve()
      })
    })
    t.event('setup', 'Production Chrome; native mouse / keyboard, read-only CDP')
    await t.key('ctrl+r')
    await t.waitForDrawing()
    console.log(`EVIDENCE_DIR=${t.out}`)
    return t
  }
  send(method, params = {}) {
    const id = ++this.sequence
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(id); reject(Error(`CDP timeout: ${method}`))
      }, 10000)
      this.pending.set(id, m => {
        clearTimeout(timeout)
        if (m.error) reject(Error(JSON.stringify(m.error)))
        else resolve(m.result)
      })
      this.ws.send(JSON.stringify({ id, method, params }))
    })
  }
  async read(expression) {
    const r = await this.send('Runtime.evaluate',
      { expression, returnByValue: true })
    if (r.exceptionDetails) throw Error(JSON.stringify(r.exceptionDetails))
    return r.result.value
  }
  event(type, label, extra = {}) {
    const e = { time: (performance.now() - this.epoch)/1000,
      type, step: this.index, label, ...extra }
    this.events.push(e)
    fs.appendFileSync(path.join(this.out, 'events.jsonl'), JSON.stringify(e)+'\n')
    console.log(JSON.stringify(e))
  }
  async step(title, fn) {
    this.index++; this.title = title
    this.event('test_start', title)
    await delay(1400) // Reading time before the actual scripted inputs.
    await fn()
    await this.snapshot('step')
    this.event('assertion', title, { result: 'passed' })
    await delay(2400) // Reading time; preserved in final uncut evidence.
  }
  async key(keys) {
    run('xdotool', ['key', '--clearmodifiers', keys])
    await delay(250)
  }
  async target(selector, text = null) {
    const r = await this.read(`(() => {
      const es = [...document.querySelectorAll(${JSON.stringify(selector)})];
      const e = es.find(e => (${JSON.stringify(text)} === null ||
        e.textContent.trim().startsWith(${JSON.stringify(text)})) &&
        e.getBoundingClientRect().width > 0);
      if (!e || e.disabled) return null;
      const b = e.getBoundingClientRect();
      const x = b.x + b.width/2, y = b.y + b.height/2;
      if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) return null;
      if (!e.contains(document.elementFromPoint(x,y))) return null;
      return [Math.round(x), Math.round(y)];
    })()`)
    assert.ok(r, `Visible unobstructed target required: ${selector} ${text}`)
    run('xdotool', ['mousemove', '--sync', ...r.map(String)])
    await delay(200)
    run('xdotool', ['click', '1'])
    await delay(300)
  }
  click(label) { return this.target(`[aria-label=${JSON.stringify(label)}]`) }
  clickText(text, selector = 'button') { return this.target(selector, text) }
  async fill(label, value, enter = true) {
    await this.click(label)
    await this.key('ctrl+a')
    if (value) run('xdotool', ['type', '--clearmodifiers', '--delay', '35', value])
    else await this.key('BackSpace')
    if (enter) await this.key('Return')
    await delay(300)
  }
  command(text) { return this.fill('Command line', text) }
  state() {
    return this.read(`(() => {
      const drawing = JSON.parse(localStorage.getItem('draev.drawing.v1'));
      const id = document.querySelector('.entity.selected')?.dataset.entity;
      return { drawing, selected: drawing.entities.find(e => e.id === id),
        rendered: document.querySelectorAll('.entity').length,
        fields: Object.fromEntries([...document.querySelectorAll('input')]
          .map(e => [e.getAttribute('aria-label'),e.value])) };
    })()`)
  }
  async snapshot(suffix) {
    const name = `${String(this.index).padStart(2,'0')}-${suffix}`
    const shot = await this.send('Page.captureScreenshot',
      { format: 'png', captureBeyondViewport: false })
    fs.writeFileSync(path.join(this.out, name+'.png'),
      Buffer.from(shot.data, 'base64'))
    fs.writeFileSync(path.join(this.out, name+'.json'),
      JSON.stringify(await this.state(), null, 2))
  }
  async equal(actual, expected, label) {
    try { assert.deepEqual(actual, expected, label) }
    catch (e) {
      this.event('assertion', label, { result: 'failed', actual, expected })
      throw e
    }
    this.event('assertion', label, { result: 'passed' })
  }
  async entity(expected) {
    const s = await this.state()
    const actual = Object.fromEntries(Object.keys(expected)
      .map(k => [k, s.selected?.[k]]))
    await this.equal(actual, expected, `Geometry ${JSON.stringify(expected)}`)
    await this.snapshot(`geometry-${this.events.length}`)
    await delay(700)
  }
  async fields(expected) {
    const fields = (await this.state()).fields
    await this.equal(Object.fromEntries(Object.keys(expected)
      .map(k => [k,fields[k]])), expected, `Properties ${JSON.stringify(expected)}`)
  }
  async layer(id, visible, count) {
    const s = await this.state()
    await this.equal(s.drawing.layers.find(l => l.id === id).visible, visible,
      `${id} visible=${visible}`)
    await this.equal(s.rendered, count, `Rendered objects=${count}`)
    await this.snapshot(`layer-${visible}`)
    await delay(1200)
  }
  async waitForDrawing(count) {
    for (let i=0; i<40; i++) {
      try {
        const s = await this.state()
        if (s.rendered > 0 && (!count || s.drawing.entities.length === count)) {
          await delay(700); return
        }
      } catch { /* Reload can briefly remove the execution context. */ }
      await delay(200)
    }
    throw Error(`Drawing did not load; expected count ${count}`)
  }
  async download(option, filename) {
    await this.click('Export drawing')
    await delay(600)
    await this.clickText(option, '.export-option')
    for (let i=0; i<50; i++) {
      if (fs.existsSync(path.join(this.out, filename))) return
      await delay(200)
    }
    throw Error(`Missing real UI download: ${filename}`)
  }
  readJSON(name) { return JSON.parse(fs.readFileSync(path.join(this.out,name))) }
  async verifyExports(drawing) {
    fs.writeFileSync(path.join(this.out,'expected.json'), JSON.stringify(drawing))
    const output = run(process.env.CU_PYTHON || '/usr/bin/python3',
      [path.join(appRoot,'scripts/computer-use-exports.py'), this.out])
    fs.writeFileSync(path.join(this.out,'export-assertions.txt'), output)
    for (const line of output.trim().split('\n')) {
      this.event('assertion', line, { result: 'passed' })
    }
    await delay(2500)
  }
  fail(error) {
    this.failed = true
    this.event('assertion', error.message, { result: 'failed' })
    console.error(error)
  }
  async finish() {
    await this.snapshot(this.failed ? 'failure' : 'final')
    this.event('summary', this.failed ? 'FAILED: see evidence' :
      'PASSED: geometry, visibility, exports and persistence',
    { result: this.failed ? 'failed' : 'passed' })
    await delay(3500)
    await new Promise(resolve => {
      this.video.once('exit', resolve); this.video.stdin.write('q\n')
    })
    fs.writeFileSync(path.join(this.out,'capture.log'), this.captureLog)
    fs.writeFileSync(path.join(this.out,'runtime-events.json'),
      JSON.stringify(this.errors,null,2))
    fs.writeFileSync(path.join(this.out,'run.json'), JSON.stringify({
      commit: run('git',['-C',appRoot,'rev-parse','HEAD']).trim(),
      source: this.source, result: this.failed ? 'failed' : 'passed',
      input: 'native xdotool', observations: 'read-only CDP',
      synchronization: 'monotonic timestamps from ffmpeg first progress',
    }, null, 2))
    this.ws.close()
    console.log(`COMPOSE: /usr/bin/python3 scripts/computer-use-compose.py ${this.out}`)
  }
}
