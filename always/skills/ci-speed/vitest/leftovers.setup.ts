// What does each test file leave behind when it ends? Appended as the last setup file by
// leaks.config.mts and run with one process per file, so nothing a file leaves can reach another.
// Three kinds, one JSON line per file that leaves any (LEAKS_OUT):
//   timers  still pending after the last test
//   events  work that keeps running in a grace window after those timers are discarded
//   state   worker-level state left changed: fake timers, env vars, replaced globals, DOM, storage
import { appendFileSync } from 'node:fs'
import { afterAll, expect, vi } from 'vitest'

const root = process.cwd() + '/'
const graceMs = Number(process.env.LEAKS_GRACE_MS ?? 400)
const realSetTimeout = globalThis.setTimeout
const realClearTimeout = globalThis.clearTimeout
const where = () => (new Error().stack ?? '').split('\n').slice(2)
  .map(line => line.trim().replace(/^at /, ''))
  .filter(line => !line.includes('node_modules') && !line.includes('leftovers.setup'))
  .slice(0, 3).map(line => line.replace(/\(?(file:\/\/)?/, '').replace(root, '').replace(/\)$/, '')).join(' < ')

const live = new Map<unknown, string>()
let grace: string[] | null = null
for (const name of ['setTimeout', 'setInterval'] as const) {
  const real = globalThis[name] as (...args: unknown[]) => unknown
  ;(globalThis as Record<string, unknown>)[name] = new Proxy(real, {
    apply(target, self, args: unknown[]) {
      const from = where()
      if (grace) grace.push(`${name} ${from}`)
      const [callback, ...rest] = args
      let handle: unknown
      const once = typeof callback === 'function' && name === 'setTimeout'
        ? (...a: unknown[]) => { live.delete(handle); return (callback as (...a: unknown[]) => unknown)(...a) }
        : callback
      handle = Reflect.apply(target, self, [once, ...rest])
      live.set(handle, `${name}(${typeof rest[0] === 'number' ? Math.round(rest[0]) : 0}ms) ${from}`)
      return handle
    }
  })
}
for (const name of ['clearTimeout', 'clearInterval'] as const) {
  const real = globalThis[name] as (...args: unknown[]) => unknown
  ;(globalThis as Record<string, unknown>)[name] = (handle: unknown) => { live.delete(handle); return real(handle) }
}

const globals = globalThis as Record<string, unknown>
const read = (key: string) => { try { return globals[key] } catch { return undefined } }
const envAtStart = { ...process.env }
const globalsAtStart = new Map(Object.getOwnPropertyNames(globalThis).map(key => [key, read(key)]))
const instrumented = /^(setTimeout|setInterval|clearTimeout|clearInterval|fetch|console)$/

function leftState(): string[] {
  const left: string[] = []
  if (vi.isFakeTimers()) left.push('fakeTimers')
  for (const key of new Set([...Object.keys(envAtStart), ...Object.keys(process.env)])) {
    if (envAtStart[key] !== process.env[key]) left.push(`env:${key}`)
  }
  for (const key of Object.getOwnPropertyNames(globalThis)) {
    if (!globalsAtStart.has(key)) left.push(`global+:${key}`)
    else if (!Object.is(globalsAtStart.get(key), read(key)) && !instrumented.test(key)) left.push(`global~:${key}`)
  }
  if (typeof window !== 'undefined') {
    if (document.body.childNodes.length) left.push('dom:body')
    try { if (window.localStorage.length) left.push('localStorage') } catch { /* storage replaced by a stub */ }
    try { if (window.sessionStorage.length) left.push('sessionStorage') } catch { /* storage replaced by a stub */ }
    if (document.cookie) left.push('cookie')
  }
  return left
}

afterAll(async () => {
  const file = (expect.getState().testPath ?? '?').replace(root, '')
  const state = leftState()
  const timers = [...live.values()]
  for (const handle of live.keys()) realClearTimeout(handle as never)
  live.clear()

  const events: string[] = []
  if (graceMs > 0) {
    grace = events
    const realFetch = globalThis.fetch
    globalThis.fetch = ((input: RequestInfo | URL) => {
      events.push(`fetch ${typeof input === 'string' ? input : input instanceof URL ? input.href : input.url} ${where()}`)
      return Promise.reject(new Error('leftovers: fetch after the file ended'))
    }) as typeof fetch
    const levels = ['log', 'info', 'warn', 'error', 'debug'] as const
    const realConsole = levels.map(level => console[level])
    levels.forEach(level => { console[level] = (...args: unknown[]) => { events.push(`console.${level} ${String(args[0]).slice(0, 70)} ${where()}`) } })
    await new Promise(resolve => realSetTimeout(resolve, graceMs))
    grace = null
    globalThis.fetch = realFetch
    levels.forEach((level, index) => { console[level] = realConsole[index] })
  }
  if (timers.length || events.length || state.length) {
    appendFileSync(process.env.LEAKS_OUT!, JSON.stringify({ file, timers, events, state }) + '\n')
  }
})
