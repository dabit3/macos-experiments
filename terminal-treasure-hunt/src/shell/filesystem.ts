export const USER = 'hunter'
export const HOST = 'treasure'
export const HOME = `/home/${USER}`
export const FLAG = 'FLAG{gr3p_th3_l0gs_d3c0de_th3_d0ts}'
export const DECOY_FLAG = 'FLAG{n1ce_try_th1s_1s_a_dec0y}'

export interface FsFile {
  kind: 'file'
  name: string
  content: string
  mode: string
  mtime: string
}

export interface FsDir {
  kind: 'dir'
  name: string
  children: Map<string, FsNode>
  mode: string
  mtime: string
}

export type FsNode = FsFile | FsDir

interface Seed {
  path: string
  content?: string
  mode?: string
  mtime?: string
}

const readme = `TREASURE HUNT

A flag of the form FLAG{...} is somewhere in this home directory.
Find it with the shell, then submit it:

    submit FLAG{...}

CLUE #1
  Files whose names start with a dot are hidden from a plain
  \`ls\`. There is a hidden directory right here in ~.

  Try:  ls -a

\`help\` lists the commands. \`man <command>\` explains one.
`

const huntNote = `CLUE #2

A worker process logged where it copied the vault key.
All logs live under ~/var/log. Search every one of them for
"vault"; the logger was inconsistent about capitalisation.

  Try:  grep -ri vault var/log

The line you want comes from the worker, not from nginx.
`

const workerLog = `2026-03-14 03:10:02 INFO  [worker-1] boot: queue=default concurrency=4
2026-03-14 03:10:02 INFO  [worker-2] boot: queue=default concurrency=4
2026-03-14 03:10:03 INFO  [worker-3] boot: queue=mail concurrency=2
2026-03-14 03:10:09 INFO  [worker-1] job 4f1c9 (thumbnail) took 118ms
2026-03-14 03:10:11 INFO  [worker-2] job 4f1ca (thumbnail) took 121ms
2026-03-14 03:10:14 WARN  [worker-3] mail: smtp connect retry 1/3
2026-03-14 03:10:15 INFO  [worker-3] mail: sent 12 messages
2026-03-14 03:11:40 INFO  [worker-1] job 4f1cb (report) took 2.4s
2026-03-14 03:12:07 ERROR [worker-2] job 4f1cc (import) failed: ENOENT data/import.csv
2026-03-14 03:12:07 INFO  [worker-2] job 4f1cc scheduled for retry in 60s
2026-03-14 03:13:07 INFO  [worker-2] job 4f1cc (import) took 890ms
2026-03-14 03:14:15 WARN  [worker-2] CLUE #3: VAULT key copied to projects/archive/deep/deeper/key.b64 (base64)
2026-03-14 03:14:16 INFO  [worker-2] job 4f1cd (cleanup) took 44ms
2026-03-14 03:15:00 INFO  [worker-1] heartbeat ok
2026-03-14 03:15:00 INFO  [worker-2] heartbeat ok
2026-03-14 03:15:00 INFO  [worker-3] heartbeat ok
2026-03-14 03:16:31 INFO  [worker-1] job 4f1ce (thumbnail) took 117ms
2026-03-14 03:18:52 WARN  [worker-3] mail: smtp connect retry 1/3
2026-03-14 03:18:53 INFO  [worker-3] mail: sent 3 messages
2026-03-14 03:20:00 INFO  [worker-1] heartbeat ok
`

const serverLog = `2026-03-14 03:09:58 INFO  server listening on :8080
2026-03-14 03:09:58 INFO  loaded 14 routes
2026-03-14 03:10:04 INFO  GET /            200 12ms
2026-03-14 03:10:05 INFO  GET /static/app.js 200 3ms
2026-03-14 03:10:21 INFO  GET /api/items   200 41ms
2026-03-14 03:10:22 WARN  GET /api/items?page=99 200 38ms (empty page)
2026-03-14 03:11:02 INFO  POST /api/login  200 88ms user=${USER}
2026-03-14 03:11:45 INFO  GET /api/report  200 2.5s
2026-03-14 03:12:30 ERROR GET /api/import  500 9ms  (see worker.log)
2026-03-14 03:14:02 INFO  GET /health      200 1ms
2026-03-14 03:15:02 INFO  GET /health      200 1ms
2026-03-14 03:16:02 INFO  GET /health      200 1ms
2026-03-14 03:17:02 INFO  GET /health      200 1ms
2026-03-14 03:18:02 INFO  GET /health      200 1ms
`

const nginxAccess = `10.0.0.12 - - [14/Mar/2026:03:10:04 +0000] "GET / HTTP/1.1" 200 5123 "-" "Mozilla/5.0"
10.0.0.12 - - [14/Mar/2026:03:10:05 +0000] "GET /static/app.js HTTP/1.1" 200 8811 "-" "Mozilla/5.0"
10.0.0.12 - - [14/Mar/2026:03:10:05 +0000] "GET /static/style.css HTTP/1.1" 200 2210 "-" "Mozilla/5.0"
10.0.0.44 - - [14/Mar/2026:03:10:33 +0000] "GET /vault HTTP/1.1" 404 153 "-" "curl/8.5.0"
10.0.0.44 - - [14/Mar/2026:03:10:34 +0000] "GET /Vault/ HTTP/1.1" 404 153 "-" "curl/8.5.0"
10.0.0.44 - - [14/Mar/2026:03:10:35 +0000] "GET /.env HTTP/1.1" 404 153 "-" "curl/8.5.0"
10.0.0.12 - - [14/Mar/2026:03:11:02 +0000] "POST /api/login HTTP/1.1" 200 312 "-" "Mozilla/5.0"
10.0.0.12 - - [14/Mar/2026:03:11:45 +0000] "GET /api/report HTTP/1.1" 200 90211 "-" "Mozilla/5.0"
10.0.0.12 - - [14/Mar/2026:03:12:30 +0000] "GET /api/import HTTP/1.1" 500 87 "-" "Mozilla/5.0"
10.0.0.9  - - [14/Mar/2026:03:14:02 +0000] "GET /health HTTP/1.1" 200 2 "-" "kube-probe/1.29"
10.0.0.9  - - [14/Mar/2026:03:15:02 +0000] "GET /health HTTP/1.1" 200 2 "-" "kube-probe/1.29"
`

const nginxError = `2026/03/14 03:10:33 [error] 812#812: *4 open() "/srv/www/vault" failed (2: No such file or directory), client: 10.0.0.44, request: "GET /vault HTTP/1.1"
2026/03/14 03:10:35 [error] 812#812: *6 open() "/srv/www/.env" failed (2: No such file or directory), client: 10.0.0.44, request: "GET /.env HTTP/1.1"
2026/03/14 03:12:30 [error] 812#812: *9 upstream prematurely closed connection while reading response header from upstream, client: 10.0.0.12, request: "GET /api/import HTTP/1.1"
`

const syslog = `Mar 14 03:09:41 ${HOST} systemd[1]: Started Daily apt download activities.
Mar 14 03:09:41 ${HOST} systemd[1]: Started Session 3 of user ${USER}.
Mar 14 03:09:55 ${HOST} systemd[1]: Started treasure-app.service.
Mar 14 03:09:58 ${HOST} treasure-app[1201]: server listening on :8080
Mar 14 03:10:02 ${HOST} treasure-worker[1210]: 3 workers online
Mar 14 03:10:33 ${HOST} nginx[812]: 404 for /vault (probe)
Mar 14 03:17:01 ${HOST} CRON[1402]: (root) CMD (cd / && run-parts --report /etc/cron.hourly)
Mar 14 03:25:00 ${HOST} systemd[1]: Starting Cleanup of Temporary Directories...
Mar 14 03:25:00 ${HOST} systemd[1]: Finished Cleanup of Temporary Directories.
`

const authLog = `Mar 14 03:09:41 ${HOST} sshd[1130]: Accepted publickey for ${USER} from 10.0.0.12 port 51422 ssh2
Mar 14 03:09:41 ${HOST} sshd[1130]: pam_unix(sshd:session): session opened for user ${USER}
Mar 14 03:10:40 ${HOST} sshd[1188]: Invalid user admin from 10.0.0.44 port 40112
Mar 14 03:10:42 ${HOST} sshd[1188]: Connection closed by invalid user admin 10.0.0.44 port 40112 [preauth]
Mar 14 03:10:51 ${HOST} sshd[1191]: Invalid user vault from 10.0.0.44 port 40120
Mar 14 03:10:53 ${HOST} sshd[1191]: Connection closed by invalid user vault 10.0.0.44 port 40120 [preauth]
Mar 14 03:11:02 ${HOST} sudo: ${USER} : TTY=pts/0 ; PWD=/home/${USER} ; USER=root ; COMMAND=/usr/bin/systemctl status treasure-app
`

const kernLog = `Mar 14 03:09:12 ${HOST} kernel: [    0.000000] Linux version 6.8.0-45-generic (buildd@lcy02-amd64-115)
Mar 14 03:09:12 ${HOST} kernel: [    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-6.8.0-45-generic root=UUID=3a2b-7f11 ro quiet
Mar 14 03:09:12 ${HOST} kernel: [    0.004521] Memory: 3934312K/4193848K available
Mar 14 03:09:13 ${HOST} kernel: [    1.201933] virtio_net virtio1 eth0: renamed from ens3
Mar 14 03:09:13 ${HOST} kernel: [    1.453120] EXT4-fs (vda1): mounted filesystem with ordered data mode.
Mar 14 03:09:14 ${HOST} kernel: [    2.011840] audit: type=1400 apparmor="STATUS" profile="unconfined"
`

const dpkgLog = `2026-03-13 22:41:07 startup archives unpack
2026-03-13 22:41:08 upgrade curl:amd64 8.5.0-2ubuntu10.5 8.5.0-2ubuntu10.6
2026-03-13 22:41:09 status installed curl:amd64 8.5.0-2ubuntu10.6
2026-03-13 22:41:12 upgrade openssl:amd64 3.0.13-0ubuntu3.4 3.0.13-0ubuntu3.5
2026-03-13 22:41:13 status installed openssl:amd64 3.0.13-0ubuntu3.5
2026-03-13 22:41:14 startup packages configure
`

const keyB64 = `Q0xVRSAjNAoKVGhlIGxhc3QgcGllY2UgaXMgaW4gfi9wcm9qZWN0cy92YXVs
dCwgYnV0IGEgcGxhaW4gbGlzdGluZwpzaG93cyBvbmx5IGRlY295cy4gTGlz
dCBldmVyeSBlbnRyeSwgaW5jbHVkaW5nIHRoZSBvbmVzIHRoYXQKc3RhcnQg
d2l0aCBhIGRvdCwgYW5kIHJlYWQgdGhlIG9uZSB5b3UgZmluZC4KCiAgICBj
ZCB+L3Byb2plY3RzL3ZhdWx0ICYmIGxzIC1hCg==
`

const vaultReadme = `THE VAULT
=========

Only decoys show up in a plain listing.
`

const vaultDecoy = `vault contents

    ${DECOY_FLAG}
`

const vaultFlag = `vault contents (real)

    ${FLAG}

Submit it with:

    submit ${FLAG}
`

const seeds: Seed[] = [
  { path: '/tmp' },
  { path: `${HOME}/README.txt`, content: readme, mtime: 'Mar 14 03:00' },
  {
    path: `${HOME}/.bashrc`,
    content: `# ~/.bashrc: executed by bash(1) for non-login shells.
export PS1='\\u@\\h:\\w\\$ '
export EDITOR=vim
alias ll='ls -la'
alias gr='grep -ri'
# nothing hidden here, keep looking
`,
    mtime: 'Mar 10 09:12',
  },
  {
    path: `${HOME}/.profile`,
    content: `# ~/.profile: executed by the command interpreter for login shells.
if [ -n "$BASH_VERSION" ]; then
  if [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi
fi
PATH="$HOME/bin:$PATH"
`,
    mtime: 'Mar 10 09:12',
  },
  { path: `${HOME}/.hunt/note.txt`, content: huntNote, mtime: 'Mar 14 03:01' },
  {
    path: `${HOME}/notes/todo.md`,
    content: `# TODO

- [x] rotate the vault key
- [x] move the encoded copy somewhere deep
- [ ] delete the worker log line that mentions it
- [ ] renew the TLS cert for treasure.local
`,
    mtime: 'Mar 13 18:40',
  },
  {
    path: `${HOME}/notes/ideas.txt`,
    content: `ideas
-----
* move logs off the home directory
* rotate worker credentials weekly
* replace backup.sh with a proper cron job
`,
    mtime: 'Mar 11 14:03',
  },
  {
    path: `${HOME}/notes/meeting-2026-03-12.md`,
    content: `# Sync 2026-03-12

Attendees: ${USER}, mara, dev

- import job keeps failing on missing CSV (owner: dev)
- nginx is getting probed for /vault and /.env, nothing exposed
- reminder: never put secrets in logs
`,
    mtime: 'Mar 12 16:20',
  },
  {
    path: `${HOME}/projects/website/index.html`,
    content: `<!doctype html>
<html>
  <head><title>treasure.local</title><link rel="stylesheet" href="style.css"></head>
  <body>
    <h1>treasure.local</h1>
    <script src="app.js"></script>
  </body>
</html>
`,
    mtime: 'Feb 28 11:02',
  },
  {
    path: `${HOME}/projects/website/style.css`,
    content: `body { font-family: system-ui, sans-serif; background: #0b0f14; color: #e6edf3; }
h1 { font-weight: 600; letter-spacing: 0.02em; }
`,
    mtime: 'Feb 28 11:02',
  },
  {
    path: `${HOME}/projects/website/app.js`,
    content: `document.querySelector('h1').dataset.ready = 'true'
`,
    mtime: 'Feb 28 11:05',
  },
  {
    path: `${HOME}/projects/archive/old-report.txt`,
    content: `Q4 report (archived)

Revenue up 4%. Infra costs flat. Import pipeline still flaky.
`,
    mtime: 'Jan 09 10:00',
  },
  { path: `${HOME}/projects/archive/deep/deeper/key.b64`, content: keyB64, mtime: 'Mar 14 03:14' },
  { path: `${HOME}/projects/archive/deep/deeper/.gitkeep`, content: '', mtime: 'Jan 09 10:00' },
  { path: `${HOME}/projects/vault/README`, content: vaultReadme, mtime: 'Mar 14 03:20' },
  { path: `${HOME}/projects/vault/decoy.txt`, content: vaultDecoy, mtime: 'Mar 14 03:20' },
  { path: `${HOME}/projects/vault/.flag`, content: vaultFlag, mode: '-r--------', mtime: 'Mar 14 03:21' },
  { path: `${HOME}/var/log/syslog`, content: syslog, mtime: 'Mar 14 03:25' },
  { path: `${HOME}/var/log/auth.log`, content: authLog, mtime: 'Mar 14 03:11' },
  { path: `${HOME}/var/log/kern.log`, content: kernLog, mtime: 'Mar 14 03:09' },
  { path: `${HOME}/var/log/dpkg.log`, content: dpkgLog, mtime: 'Mar 13 22:41' },
  { path: `${HOME}/var/log/app/server.log`, content: serverLog, mtime: 'Mar 14 03:18' },
  { path: `${HOME}/var/log/app/worker.log`, content: workerLog, mtime: 'Mar 14 03:20' },
  { path: `${HOME}/var/log/nginx/access.log`, content: nginxAccess, mtime: 'Mar 14 03:15' },
  { path: `${HOME}/var/log/nginx/error.log`, content: nginxError, mtime: 'Mar 14 03:12' },
  {
    path: `${HOME}/etc/hosts`,
    content: `127.0.0.1   localhost
127.0.1.1   ${HOST}
10.0.0.12   workstation
10.0.0.44   scanner.internal
`,
    mtime: 'Mar 01 08:00',
  },
  {
    path: `${HOME}/etc/motd`,
    content: `Welcome to ${HOST} (Ubuntu 24.04 LTS).
`,
    mtime: 'Mar 01 08:00',
  },
  {
    path: `${HOME}/etc/passwd`,
    content: `root:x:0:0:root:/root:/bin/bash
${USER}:x:1000:1000:hunter:/home/${USER}:/bin/bash
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
`,
    mtime: 'Mar 01 08:00',
  },
  {
    path: `${HOME}/etc/treasure.conf`,
    content: `# treasure.conf
[hunt]
clues = 5
flag_format = FLAG{...}
vault = ~/projects/vault
`,
    mtime: 'Mar 14 03:00',
  },
  {
    path: `${HOME}/bin/hello.sh`,
    content: `#!/bin/sh
echo "hello, $USER"
`,
    mode: '-rwxr-xr-x',
    mtime: 'Feb 02 12:00',
  },
  {
    path: `${HOME}/bin/backup.sh`,
    content: `#!/bin/sh
# nightly backup of the vault (contents redacted from this copy)
tar czf /tmp/vault-$(date +%F).tgz "$HOME/projects/vault"
`,
    mode: '-rwxr-xr-x',
    mtime: 'Feb 02 12:00',
  },
  {
    path: `${HOME}/docs/manual.txt`,
    content: `Field notes

  ls -a        show hidden entries (names beginning with a dot)
  ls -la       long listing including hidden entries
  grep -ri X D search directory D recursively, ignoring case
  base64 -d F  decode a base64 file
  find . -name 'pattern'
  submit FLAG{...}

Tab completes commands and paths. Up/Down walk the history.
`,
    mtime: 'Mar 05 09:30',
  },
  {
    path: `${HOME}/docs/faq.txt`,
    content: `Q: Is this a real shell?
A: No. Every command runs in the browser against an in-memory filesystem.

Q: Where do I start?
A: cat ~/README.txt
`,
    mtime: 'Mar 05 09:31',
  },
  {
    path: `${HOME}/pictures/map.txt`,
    content: `                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
             ~~~~        .   .  .        ~~~~
          ~~~~   /\\      . .:. .     /\\      ~~~~
        ~~~    /  \\      .:::.     /  \\   .    ~~~
       ~~     /    \\   .  ':'  .  /    \\        ~~
       ~~    /______\\      X     /______\\       ~~
        ~~~         .               .      ~~~
          ~~~~   . . .         . . .        ~~~~
             ~~~~                        ~~~~
                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
`,
    mtime: 'Feb 14 20:00',
  },
]

function makeDir(name: string, mtime = 'Mar 14 03:00'): FsDir {
  return { kind: 'dir', name, children: new Map(), mode: 'drwxr-xr-x', mtime }
}

export function buildFilesystem(): FsDir {
  const root = makeDir('/')
  for (const seed of seeds) {
    const parts = seed.path.split('/').filter(Boolean)
    let dir = root
    const isDir = seed.content === undefined
    const dirParts = isDir ? parts : parts.slice(0, -1)
    for (const part of dirParts) {
      let next = dir.children.get(part)
      if (!next) {
        next = makeDir(part, seed.mtime)
        dir.children.set(part, next)
      }
      if (next.kind !== 'dir') throw new Error(`${part} is not a directory`)
      dir = next
    }
    if (!isDir) {
      const name = parts[parts.length - 1]
      dir.children.set(name, {
        kind: 'file',
        name,
        content: seed.content ?? '',
        mode: seed.mode ?? '-rw-r--r--',
        mtime: seed.mtime ?? 'Mar 14 03:00',
      })
    }
  }
  return root
}

export function normalizePath(cwd: string, input: string): string {
  let raw = input
  if (raw === '' || raw === '~') raw = HOME
  else if (raw.startsWith('~/')) raw = HOME + raw.slice(1)
  const abs = raw.startsWith('/') ? raw : `${cwd}/${raw}`
  const out: string[] = []
  for (const part of abs.split('/')) {
    if (part === '' || part === '.') continue
    if (part === '..') out.pop()
    else out.push(part)
  }
  return '/' + out.join('/')
}

export function resolve(root: FsDir, absPath: string): FsNode | undefined {
  if (absPath === '/') return root
  let node: FsNode = root
  for (const part of absPath.split('/').filter(Boolean)) {
    if (node.kind !== 'dir') return undefined
    const next = node.children.get(part)
    if (!next) return undefined
    node = next
  }
  return node
}

export function displayPath(absPath: string): string {
  if (absPath === HOME) return '~'
  if (absPath.startsWith(HOME + '/')) return '~' + absPath.slice(HOME.length)
  return absPath
}

export function sortedChildren(dir: FsDir, all: boolean): FsNode[] {
  return [...dir.children.values()]
    .filter((n) => all || !n.name.startsWith('.'))
    .sort((a, b) => a.name.replace(/^\./, '').localeCompare(b.name.replace(/^\./, '')))
}

export function walk(dir: FsDir, base: string, visit: (node: FsNode, path: string) => void): void {
  for (const child of sortedChildren(dir, true)) {
    const path = base === '/' ? `/${child.name}` : `${base}/${child.name}`
    visit(child, path)
    if (child.kind === 'dir') walk(child, path, visit)
  }
}

export function countNodes(dir: FsDir): number {
  let n = 0
  walk(dir, '/', () => n++)
  return n
}
