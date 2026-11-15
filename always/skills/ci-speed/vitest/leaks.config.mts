// The repo's own Vitest config with one change, chosen by LEAKS_MODE:
//   census  one process per file, plus leftovers.setup.ts as the last setup file
//   replay  one worker, files in the order listed in LEAKS_ORDER (one path per line)
// Run from the repo root. LEAKS_CONFIG names the base config (default vitest.config.ts).
// No package imports: this file lives outside the repo and cannot resolve the repo's packages.
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const root = process.cwd()
const loaded = (await import(pathToFileURL(path.resolve(root, process.env.LEAKS_CONFIG ?? 'vitest.config.ts')).href)).default
const base = typeof loaded === 'function' ? await loaded({ command: 'serve', mode: 'test' }) : await loaded
const test = base.test ?? {}

type Spec = { moduleId: string }
const order = process.env.LEAKS_ORDER ? readFileSync(process.env.LEAKS_ORDER, 'utf8').trim().split('\n') : []
class Listed {
  async shard(files: Spec[]) { return files }
  async sort(files: Spec[]) {
    const at = (file: Spec) => order.findIndex(listed => file.moduleId.endsWith(listed))
    return [...files].sort((a, b) => at(a) - at(b))
  }
}

const mode = process.env.LEAKS_MODE
if (mode !== 'census' && mode !== 'replay') throw new Error('LEAKS_MODE must be census or replay')

export default {
  ...base,
  root,
  // The setup file lives outside the repo; browser-like test files load it through the dev server.
  server: { ...base.server, fs: { ...base.server?.fs, strict: false } },
  test: mode === 'census'
    ? { ...test, isolate: true, setupFiles: [...[test.setupFiles ?? []].flat(), path.join(here, 'leftovers.setup.ts')] }
    : { ...test, fileParallelism: false, sequence: { ...test.sequence, sequencer: Listed } }
}
