import type { SessionUsage } from 'claude-code'
import { expect, test } from 'claude-code/testing'

const BAND = {
  plugin: 'usage-meters',
  component: 'SessionMode',
  surface: 'terminal',
  props: { modes: [] },
} as const

const week = (percentUsed: number) => [{ kind: 'seven_day', percentUsed }]

// A compaction raises no session.measure: only `usage` moves, so the band has to read it.
test('a compaction clears the context figure before the next measurement', async ($, on) => {
  let usage: Pick<SessionUsage, 'context' | 'rateLimits'> = {
    context: { window: 1_000_000, tokens: 370_000 },
    rateLimits: week(40),
  }
  on('session.usage', () => ({ value: { startedAt: 0, ...usage } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('clock.now', () => ({ value: 0 }))
  on('clock.every', () => ({ value: undefined }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  const ui = await $.ui.mount(BAND)
  expect((await ui.find({ type: 'Text', text: /370k/ }))?.text).toBe('370k')

  usage = { context: { window: 1_000_000 }, rateLimits: week(40) }
  await ui.redraw()
  expect(await ui.find({ type: 'Text', text: /370k/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /40%/ })).toBeDefined()

  usage = { context: { window: 1_000_000, tokens: 80_000 }, rateLimits: week(41) }
  await ui.redraw()
  expect((await ui.find({ type: 'Text', text: /80k/ }))?.text).toBe('80k')
  expect(await ui.find({ type: 'Text', text: /41%/ })).toBeDefined()
  await ui.unmount()
})

// The breakdown is an estimate over the whole session, too dear for a redraw; a model switch is what moves it.
test('the compaction point is recounted only when the window changes', async ($, on) => {
  let window = 1_000_000
  let recounts = 0
  on('session.usage', (_, e) => {
    if (e?.breakdown) recounts += 1
    return { value: { startedAt: 0, context: { window, tokens: 1000 }, rateLimits: [] } }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('clock.now', () => ({ value: 0 }))
  on('clock.every', () => ({ value: undefined }))
  on('session.measure', (_, e) => ({ changed: e.changed }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  expect(recounts).toBe(1)

  const ui = await $.ui.mount(BAND)
  await ui.redraw()
  await $.session.measure({ context: { window, tokens: 2000 }, rateLimits: [], changed: ['context'] })
  expect(recounts).toBe(1)

  window = 200_000
  await $.session.measure({ context: { window, tokens: 2000 }, rateLimits: [], changed: ['context'] })
  expect(recounts).toBe(2)
  await ui.unmount()
})
