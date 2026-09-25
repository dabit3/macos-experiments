import {
  buildFilesystem,
  displayPath,
  FLAG,
  HOME,
  HOST,
  normalizePath,
  resolve,
  sortedChildren,
  USER,
  walk,
  type FsDir,
  type FsNode,
} from './filesystem'
import { COMMAND_NAMES, MAN_PAGES } from './man'
import { highlight, lineText, plain, span, styled, textLines, type Line } from './output'
import { globToRegExp, parse, parseFlags, type SimpleCommand } from './parse'

export const TOTAL_CLUES = 5
const TERMINAL_COLUMNS = 96
const FROZEN_DATE = 'Sat Mar 14 03:14:15 UTC 2026'

const CLUE_MARKERS: Array<[number, string]> = [
  [1, 'CLUE #1'],
  [2, 'CLUE #2'],
  [3, 'CLUE #3'],
  [4, 'CLUE #4'],
  [5, FLAG],
]

export interface ExecResult {
  lines: Line[]
  clear: boolean
  fireworks: boolean
}

export type Completion =
  | { kind: 'none' }
  | { kind: 'single'; value: string }
  | { kind: 'multiple'; value: string; candidates: string[] }

interface CommandIO {
  args: string[]
  stdin: string[] | null
}

interface CommandOutput {
  lines: Line[]
  status: number
}

type CommandFn = (io: CommandIO) => CommandOutput

const ok = (lines: Line[]): CommandOutput => ({ lines, status: 0 })
const fail = (msg: string): CommandOutput => ({ lines: [styled(msg, 'error')], status: 1 })

export class Shell {
  readonly root: FsDir
  cwd = HOME
  private prevCwd = HOME
  readonly history: string[] = []
  readonly clues = new Set<number>()
  solved = false
  solvedAfterCommands: number | null = null

  private readonly commands: Record<string, CommandFn>

  constructor() {
    this.root = buildFilesystem()
    this.commands = {
      ls: (io) => this.ls(io),
      cd: (io) => this.cd(io),
      pwd: () => ok([plain(this.cwd)]),
      cat: (io) => this.cat(io),
      grep: (io) => this.grep(io),
      find: (io) => this.find(io),
      echo: (io) => this.echo(io),
      base64: (io) => this.base64(io),
      head: (io) => this.headTail(io, 'head'),
      tail: (io) => this.headTail(io, 'tail'),
      wc: (io) => this.wc(io),
      tree: (io) => this.tree(io),
      history: () => ok(this.history.map((h, i) => [span(String(i + 1).padStart(5) + '  ', 'muted'), span(h)])),
      clear: () => ok([]),
      help: () => this.help(),
      man: (io) => this.man(io),
      submit: (io) => this.submit(io),
      whoami: () => ok([plain(USER)]),
      hostname: () => ok([plain(HOST)]),
      date: () => ok([plain(FROZEN_DATE)]),
      exit: () => ok([styled('logout: there is nowhere to go. This is a browser.', 'muted')]),
    }
  }

  get prompt(): string {
    return `${USER}@${HOST}:${displayPath(this.cwd)}$ `
  }

  /** Execute one raw line of input. */
  execute(raw: string): ExecResult {
    const line = raw.trim()
    const result: ExecResult = { lines: [], clear: false, fireworks: false }
    if (!line) return result
    this.history.push(line)

    for (const pipeline of parse(line)) {
      let stdin: string[] | null = null
      let status = 0
      let output: Line[] = []
      for (const cmd of pipeline) {
        if (cmd.name === 'clear') {
          result.clear = true
          result.lines = []
          output = []
          continue
        }
        const out = this.run(cmd, stdin)
        status = out.status
        output = out.lines
        stdin = out.lines.map(lineText)
        if (status !== 0) break
      }
      result.lines.push(...output)
      if (this.solved && this.solvedAfterCommands === this.history.length) result.fireworks = true
      if (status !== 0) break
    }

    const text = result.lines.map(lineText).join('\n')
    for (const [n, marker] of CLUE_MARKERS) if (text.includes(marker)) this.clues.add(n)
    return result
  }

  private run(cmd: SimpleCommand, stdin: string[] | null): CommandOutput {
    const fn = this.commands[cmd.name]
    if (!fn) {
      const suggestion = COMMAND_NAMES.find((c) => c.startsWith(cmd.name[0]) && c.length <= cmd.name.length + 2)
      return fail(`${cmd.name}: command not found` + (suggestion ? `  (did you mean \`${suggestion}\`?)` : ''))
    }
    return fn({ args: cmd.args, stdin })
  }

  // ---- path helpers -------------------------------------------------------

  private lookup(path: string): { abs: string; node: FsNode | undefined } {
    const abs = normalizePath(this.cwd, path)
    return { abs, node: resolve(this.root, abs) }
  }

  /** Expand a `*`/`?` glob in the last path segment; returns the arg unchanged when nothing matches. */
  private expandGlobs(args: string[]): string[] {
    const out: string[] = []
    for (const arg of args) {
      if (!/[*?]/.test(arg)) {
        out.push(arg)
        continue
      }
      const slash = arg.lastIndexOf('/')
      const dirPart = slash >= 0 ? arg.slice(0, slash) : ''
      const pattern = slash >= 0 ? arg.slice(slash + 1) : arg
      const { node } = this.lookup(dirPart === '' ? '.' : dirPart)
      if (!node || node.kind !== 'dir') {
        out.push(arg)
        continue
      }
      const re = globToRegExp(pattern)
      const matches = sortedChildren(node, pattern.startsWith('.'))
        .filter((c) => re.test(c.name))
        .map((c) => (dirPart ? `${dirPart}/${c.name}` : c.name))
      out.push(...(matches.length ? matches : [arg]))
    }
    return out
  }

  private readFile(path: string, cmd: string): { lines: string[] } | { error: string } {
    const { node } = this.lookup(path)
    if (!node) return { error: `${cmd}: ${path}: No such file or directory` }
    if (node.kind === 'dir') return { error: `${cmd}: ${path}: Is a directory` }
    const lines = node.content.split('\n')
    if (lines.length > 1 && lines[lines.length - 1] === '') lines.pop()
    return { lines }
  }

  private inputLines(io: CommandIO, cmd: string, paths: string[]): { lines: string[] } | { error: string } {
    if (paths.length === 0) {
      if (io.stdin) return { lines: io.stdin }
      return { error: `${cmd}: missing file operand (or pipe something into it)` }
    }
    const all: string[] = []
    for (const p of paths) {
      const r = this.readFile(p, cmd)
      if ('error' in r) return r
      all.push(...r.lines)
    }
    return { lines: all }
  }

  // ---- commands -----------------------------------------------------------

  private nameSpan(node: FsNode) {
    const style = node.kind === 'dir' ? 'dir' : node.mode.includes('x') ? 'exec' : node.name.startsWith('.') ? 'hidden' : undefined
    return span(node.kind === 'dir' ? `${node.name}/` : node.name, style)
  }

  private ls(io: CommandIO): CommandOutput {
    const { flags, positional } = parseFlags(io.args)
    const all = flags.has('a') || flags.has('A')
    const long = flags.has('l')
    const targets = this.expandGlobs(positional.length ? positional : ['.'])
    const lines: Line[] = []
    let status = 0
    targets.forEach((target, idx) => {
      const { node } = this.lookup(target)
      if (!node) {
        lines.push(styled(`ls: cannot access '${target}': No such file or directory`, 'error'))
        status = 2
        return
      }
      if (targets.length > 1) {
        if (idx > 0) lines.push(plain(''))
        lines.push([span(`${target}:`, 'heading')])
      }
      const entries = node.kind === 'dir' ? sortedChildren(node, all) : [node]
      if (node.kind === 'dir' && all) {
        entries.unshift(
          { kind: 'dir', name: '.', children: new Map(), mode: node.mode, mtime: node.mtime },
          { kind: 'dir', name: '..', children: new Map(), mode: 'drwxr-xr-x', mtime: node.mtime },
        )
      }
      if (long) {
        lines.push([span(`total ${entries.length}`, 'muted')])
        for (const e of entries) {
          const size = e.kind === 'dir' ? 4096 : e.content.length
          const links = e.kind === 'dir' ? e.children.size + 2 : 1
          lines.push([
            span(`${e.mode} ${String(links).padStart(2)} ${USER.padEnd(7)} ${USER.padEnd(7)} ${String(size).padStart(6)} ${e.mtime} `, 'muted'),
            this.nameSpan(e),
          ])
        }
      } else {
        lines.push(...this.columns(entries))
      }
    })
    return { lines, status }
  }

  private columns(entries: FsNode[]): Line[] {
    if (entries.length === 0) return []
    const width = Math.max(...entries.map((e) => e.name.length + (e.kind === 'dir' ? 1 : 0))) + 2
    const perRow = Math.max(1, Math.floor(TERMINAL_COLUMNS / width))
    const rows = Math.ceil(entries.length / perRow)
    const lines: Line[] = []
    for (let r = 0; r < rows; r++) {
      const line: Line = []
      for (let c = 0; c < perRow; c++) {
        const e = entries[c * rows + r]
        if (!e) continue
        const s = this.nameSpan(e)
        line.push(s)
        if (c * rows + r + rows < entries.length) line.push(span(' '.repeat(width - s.text.length)))
      }
      lines.push(line)
    }
    return lines
  }

  private cd(io: CommandIO): CommandOutput {
    const target = io.args[0] ?? '~'
    const dest = target === '-' ? this.prevCwd : target
    const { abs, node } = this.lookup(dest)
    if (!node) return fail(`cd: no such file or directory: ${target}`)
    if (node.kind !== 'dir') return fail(`cd: not a directory: ${target}`)
    this.prevCwd = this.cwd
    this.cwd = abs
    return ok(target === '-' ? [plain(abs)] : [])
  }

  private cat(io: CommandIO): CommandOutput {
    const paths = this.expandGlobs(io.args)
    const r = this.inputLines(io, 'cat', paths)
    if ('error' in r) return fail(r.error)
    return ok(r.lines.map(plain))
  }

  private grep(io: CommandIO): CommandOutput {
    const { flags, positional } = parseFlags(io.args)
    if (positional.length === 0) return fail('usage: grep [-r] [-i] [-n] [-v] pattern [path...]')
    const [pattern, ...rawPaths] = positional
    const paths = this.expandGlobs(rawPaths)
    const recursive = flags.has('r') || flags.has('R')
    const ignoreCase = flags.has('i')
    const numbers = flags.has('n')
    const invert = flags.has('v')
    let re: RegExp
    try {
      re = new RegExp(pattern, ignoreCase ? 'i' : '')
    } catch {
      re = new RegExp(pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), ignoreCase ? 'i' : '')
    }

    const sources: Array<{ label: string; lines: string[] }> = []
    const errors: Line[] = []
    if (paths.length === 0) {
      if (recursive) paths.push('.')
      else if (io.stdin) sources.push({ label: '', lines: io.stdin })
      else return fail('grep: no input. Give it a path (or -r for a directory), or pipe text into it.')
    }
    for (const p of paths) {
      const { abs, node } = this.lookup(p)
      if (!node) {
        errors.push(styled(`grep: ${p}: No such file or directory`, 'error'))
        continue
      }
      if (node.kind === 'dir') {
        if (!recursive) {
          errors.push(styled(`grep: ${p}: Is a directory (use -r to search inside it)`, 'error'))
          continue
        }
        walk(node, abs, (child, childAbs) => {
          if (child.kind !== 'file') return
          const rel = p === '.' ? '.' + childAbs.slice(abs.length) : p.replace(/\/$/, '') + childAbs.slice(abs.length)
          sources.push({ label: rel, lines: fileLines(child.content) })
        })
      } else sources.push({ label: p, lines: fileLines(node.content) })
    }

    const showLabel = sources.length > 1
    const out: Line[] = [...errors]
    let matched = 0
    for (const src of sources) {
      src.lines.forEach((text, i) => {
        const hit = re.test(text)
        if (hit === invert) return
        matched++
        const line: Line = []
        if (showLabel && src.label) line.push(span(src.label, 'accent'), span(':', 'muted'))
        if (numbers) line.push(span(String(i + 1), 'success'), span(':', 'muted'))
        line.push(...(invert ? [span(text)] : highlight(text, re)))
        out.push(line)
      })
    }
    return { lines: out, status: matched > 0 ? 0 : 1 }
  }

  private find(io: CommandIO): CommandOutput {
    const paths: string[] = []
    let namePattern: RegExp | null = null
    let type: 'f' | 'd' | null = null
    for (let i = 0; i < io.args.length; i++) {
      const a = io.args[i]
      if (a === '-name' || a === '-iname') {
        const v = io.args[++i]
        if (v === undefined) return fail(`find: missing argument to \`${a}'`)
        namePattern = globToRegExp(v)
        if (a === '-iname') namePattern = new RegExp(namePattern.source, 'i')
      } else if (a === '-type') {
        const v = io.args[++i]
        if (v !== 'f' && v !== 'd') return fail(`find: Unknown argument to -type: ${v ?? ''}`)
        type = v
      } else if (a.startsWith('-')) return fail(`find: unknown predicate \`${a}'`)
      else paths.push(a)
    }
    if (paths.length === 0) paths.push('.')
    const out: Line[] = []
    let status = 0
    for (const p of paths) {
      const { abs, node } = this.lookup(p)
      if (!node) {
        out.push(styled(`find: '${p}': No such file or directory`, 'error'))
        status = 1
        continue
      }
      const base = p.replace(/\/+$/, '') || '/'
      const keep = (n: FsNode) => (!type || (type === 'd') === (n.kind === 'dir')) && (!namePattern || namePattern.test(n.name))
      if (keep(node)) out.push([span(base, node.kind === 'dir' ? 'dir' : undefined)])
      if (node.kind === 'dir') {
        walk(node, abs, (child, childAbs) => {
          if (!keep(child)) return
          const rel = (base === '/' ? '' : base) + childAbs.slice(abs.length)
          out.push([span(rel, child.kind === 'dir' ? 'dir' : child.name.startsWith('.') ? 'hidden' : undefined)])
        })
      }
    }
    return { lines: out, status }
  }

  private echo(io: CommandIO): CommandOutput {
    const vars: Record<string, string> = { HOME, USER, PWD: this.cwd, HOSTNAME: HOST, FLAG_FORMAT: 'FLAG{...}', SHELL: '/bin/fakesh' }
    const args = io.args[0] === '-n' ? io.args.slice(1) : io.args
    const text = args.map((a) => a.replace(/\$(\w+)/g, (_, k: string) => vars[k] ?? '')).join(' ')
    return ok([plain(text)])
  }

  private base64(io: CommandIO): CommandOutput {
    const { flags, positional } = parseFlags(io.args)
    const r = this.inputLines(io, 'base64', positional)
    if ('error' in r) return fail(r.error)
    if (flags.has('d') || flags.has('decode')) {
      const compact = r.lines.join('').replace(/\s+/g, '')
      if (!/^[A-Za-z0-9+/]*={0,2}$/.test(compact) || compact.length % 4 === 1) return fail('base64: invalid input')
      try {
        const bytes = Uint8Array.from(atob(compact), (c) => c.charCodeAt(0))
        return ok(textLines(new TextDecoder().decode(bytes)))
      } catch {
        return fail('base64: invalid input')
      }
    }
    const bytes = new TextEncoder().encode(r.lines.join('\n') + '\n')
    let bin = ''
    for (const b of bytes) bin += String.fromCharCode(b)
    const encoded = btoa(bin)
    return ok((encoded.match(/.{1,76}/g) ?? ['']).map(plain))
  }

  private headTail(io: CommandIO, which: 'head' | 'tail'): CommandOutput {
    const { values, positional } = parseFlags(io.args, ['n'])
    const n = Number.parseInt(values.get('n') ?? '10', 10)
    if (!Number.isFinite(n) || n < 0) return fail(`${which}: invalid number of lines: '${values.get('n')}'`)
    const paths = this.expandGlobs(positional)
    const r = this.inputLines(io, which, paths)
    if ('error' in r) return fail(r.error)
    const picked = which === 'head' ? r.lines.slice(0, n) : r.lines.slice(Math.max(0, r.lines.length - n))
    return ok(picked.map(plain))
  }

  private wc(io: CommandIO): CommandOutput {
    const { flags, positional } = parseFlags(io.args)
    const paths = this.expandGlobs(positional)
    const only = flags.has('l') ? 'l' : flags.has('w') ? 'w' : flags.has('c') ? 'c' : null
    const rows: Array<{ l: number; w: number; c: number; label: string }> = []
    const errors: Line[] = []
    const count = (lines: string[], label: string) => {
      const text = lines.join('\n') + (lines.length ? '\n' : '')
      rows.push({ l: lines.length, w: text.split(/\s+/).filter(Boolean).length, c: new TextEncoder().encode(text).length, label })
    }
    if (paths.length === 0) {
      if (!io.stdin) return fail('wc: missing file operand (or pipe something into it)')
      count(io.stdin, '')
    } else {
      for (const p of paths) {
        const r = this.readFile(p, 'wc')
        if ('error' in r) errors.push(styled(r.error, 'error'))
        else count(r.lines, p)
      }
      if (rows.length > 1) rows.push(rows.reduce((t, r) => ({ l: t.l + r.l, w: t.w + r.w, c: t.c + r.c, label: 'total' }), { l: 0, w: 0, c: 0, label: 'total' }))
    }
    const fmt = (r: (typeof rows)[number]) => {
      const cols = only === 'l' ? [r.l] : only === 'w' ? [r.w] : only === 'c' ? [r.c] : [r.l, r.w, r.c]
      return [span(cols.map((v) => String(v).padStart(7)).join('')), span(r.label ? ` ${r.label}` : '', 'accent')]
    }
    return { lines: [...errors, ...rows.map(fmt)], status: errors.length ? 1 : 0 }
  }

  private tree(io: CommandIO): CommandOutput {
    const { flags, positional } = parseFlags(io.args)
    const all = flags.has('a')
    const target = positional[0] ?? '.'
    const { node } = this.lookup(target)
    if (!node) return fail(`tree: ${target}: No such file or directory`)
    if (node.kind !== 'dir') return ok([plain(target)])
    const lines: Line[] = [[span(target, 'dir')]]
    let dirs = 0
    let files = 0
    const rec = (dir: FsDir, prefix: string) => {
      const kids = sortedChildren(dir, all)
      kids.forEach((kid, i) => {
        const last = i === kids.length - 1
        lines.push([span(prefix + (last ? '└── ' : '├── '), 'muted'), this.nameSpan(kid)])
        if (kid.kind === 'dir') {
          dirs++
          rec(kid, prefix + (last ? '    ' : '│   '))
        } else files++
      })
    }
    rec(node, '')
    lines.push(plain(''), [span(`${dirs} directories, ${files} files`, 'muted')])
    return ok(lines)
  }

  private help(): CommandOutput {
    const lines: Line[] = [[span('Available commands', 'heading')], plain('')]
    for (const name of COMMAND_NAMES) {
      const page = MAN_PAGES[name]
      lines.push([span('  ' + page.synopsis.padEnd(44), 'accent'), span(page.summary, 'muted')])
    }
    lines.push(
      plain(''),
      [span('  Tab', 'success'), span(' completes commands and paths   ', 'muted'), span('Up/Down', 'success'), span(' recall history   ', 'muted'), span('Ctrl+L', 'success'), span(' clears', 'muted')],
      [span('  Pipes work: ', 'muted'), span('grep -ri vault var/log | wc -l', 'plain')],
    )
    return ok(lines)
  }

  private man(io: CommandIO): CommandOutput {
    const name = io.args[0]
    if (!name) return fail('What manual page do you want?  e.g. `man grep`')
    const page = MAN_PAGES[name]
    if (!page) return fail(`No manual entry for ${name}`)
    const lines: Line[] = [
      [span(`${page.name.toUpperCase()}(1)`, 'muted'), span(`${' '.repeat(Math.max(1, 40 - page.name.length))}User Commands`, 'muted')],
      plain(''),
      [span('NAME', 'heading')],
      plain(`       ${page.name} - ${page.summary}`),
      plain(''),
      [span('SYNOPSIS', 'heading')],
      [span('       ' + page.synopsis, 'accent')],
      plain(''),
      [span('DESCRIPTION', 'heading')],
      ...page.description.map((d) => plain('       ' + d)),
      plain(''),
      [span('EXAMPLES', 'heading')],
      ...page.examples.map((e) => [span('       $ ', 'muted'), span(e, 'success')]),
    ]
    return ok(lines)
  }

  private submit(io: CommandIO): CommandOutput {
    const guess = io.args.join(' ').trim()
    if (!guess) return fail('usage: submit FLAG{...}')
    if (this.solved) return ok([styled('submit: already solved', 'muted')])
    if (guess !== FLAG) {
      const hint = /^FLAG\{.*\}$/.test(guess) ? 'decoys show up in a plain listing; the real flag does not' : 'expected FLAG{...}'
      return { lines: [[span('submit: incorrect flag', 'error'), span(` \u2014 ${hint}`, 'muted')]], status: 1 }
    }
    this.solved = true
    this.solvedAfterCommands = this.history.length
    this.clues.add(5)
    return ok([])
  }

  // ---- completion -----------------------------------------------------------

  complete(input: string): Completion {
    const lastSpace = Math.max(input.lastIndexOf(' '), input.lastIndexOf('|'), input.lastIndexOf(';'))
    const head = input.slice(0, lastSpace + 1)
    const word = input.slice(lastSpace + 1)
    const isCommand = head.trim() === '' || /[|;&]\s*$/.test(head)
    if (isCommand) return finish(head, word, COMMAND_NAMES.filter((c) => c.startsWith(word)).map((c) => ({ text: c, isDir: false })))

    const segment = head.split(/[|;&]/).pop() ?? ''
    const cmdName = segment.trim().split(/\s+/)[0]
    const dirsOnly = cmdName === 'cd'
    const slash = word.lastIndexOf('/')
    const dirPart = slash >= 0 ? word.slice(0, slash + 1) : ''
    const prefix = word.slice(slash + 1)
    const { node } = this.lookup(dirPart === '' ? '.' : dirPart)
    if (!node || node.kind !== 'dir') return { kind: 'none' }
    const candidates = sortedChildren(node, prefix.startsWith('.'))
      .filter((c) => c.name.startsWith(prefix) && (!dirsOnly || c.kind === 'dir'))
      .map((c) => ({ text: c.name, isDir: c.kind === 'dir' }))
    return finish(head + dirPart, prefix, candidates)
  }
}

function fileLines(content: string): string[] {
  const lines = content.split('\n')
  if (lines.length > 1 && lines[lines.length - 1] === '') lines.pop()
  return lines
}

function finish(base: string, typed: string, candidates: Array<{ text: string; isDir: boolean }>): Completion {
  if (candidates.length === 0) return { kind: 'none' }
  if (candidates.length === 1) {
    const c = candidates[0]
    return { kind: 'single', value: base + c.text + (c.isDir ? '/' : ' ') }
  }
  let common = candidates[0].text
  for (const c of candidates) {
    let i = 0
    while (i < common.length && i < c.text.length && common[i] === c.text[i]) i++
    common = common.slice(0, i)
  }
  if (common.length < typed.length) common = typed
  return { kind: 'multiple', value: base + common, candidates: candidates.map((c) => c.text + (c.isDir ? '/' : '')) }
}
