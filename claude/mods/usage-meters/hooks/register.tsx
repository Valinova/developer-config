import { atom, read, update } from 'claude-code'
import type { Register, SessionContextUsage, SessionUsage } from 'claude-code'

import type { Snapshot } from '../types'

const snapshot = atom({ plugin: 'usage-meters', key: 'snapshot' } as const, null, { shape: 'snapshot-3' })
const pet = atom({ plugin: 'usage-meters', key: 'pet' } as const, null)
// Persisted so the brain shows at startup, before this session's first request reports a level.
const effort = atom({ plugin: 'usage-meters', key: 'effort' } as const, null)

const CELLS = 5
const WAVE = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
const TRACK = '#2a1d17'
const TRACK_RGB: RGB = [42, 29, 23]
// Between turns the meters stir for a few seconds, then rest.
const BURST_EVERY_S = 30
const BURST_FOR_S = 8
const TICK_MS = 250
const SLEEP_AFTER_MS = 5 * 60_000
const PET_LIFETIME_MS = 60 * 60_000
// Ember+Pop: Claude's orange between brown and gold, with an electric cyan accent.
const CALM: RGB[] = [[124, 63, 29], [217, 119, 87], [255, 179, 71]] // brown → Claude orange → gold
const HOT: RGB[] = [[217, 119, 87], [255, 107, 74], [255, 77, 109]] // orange → hot pink-red, past 85%
const POP: RGB = [34, 211, 238] // electric cyan
const GOLD: RGB = [255, 179, 71]

type RGB = [number, number, number]
type Mood = 'idle' | 'working' | 'waiting' | 'sleeping' | 'stuffed'

const EFFORT_STEPS = ['▁', '▃', '▅', '▇', '█']
const EFFORT_LEVELS = ['low', 'medium', 'high', 'xhigh', 'max']
const EFFORT_LETTERS = ['L', 'M', 'H', 'XH', 'MAX']

const E = Symbol('eye')
const M = Symbol('mouth')
type Species = {
  parts: (string | typeof E | typeof M)[]
  mouth: [rest: string, busy: string]
  body: string
  eye: string
}

const SPECIES: Species[] = [
  { parts: ['=^', E, M, E, '^='], mouth: ['ω', 'o'], body: '#ffb347', eye: '#22d3ee' }, // cat
  { parts: ['ʕ', E, M, E, 'ʔ'], mouth: ['ᴥ', 'o'], body: '#c97a40', eye: '#22d3ee' }, // bear
  { parts: ['(', E, M, E, ')'], mouth: ['ᴗ', 'o'], body: '#d97757', eye: '#22d3ee' }, // blob
  { parts: ['{', E, ',', E, '}'], mouth: ['', ''], body: '#ffcf70', eye: '#22d3ee' }, // owl
  { parts: ['[', E, M, E, ']'], mouth: ['_', '-'], body: '#e0a96d', eye: '#22d3ee' }, // robot
  { parts: ['><(((', E, '>'], mouth: ['', ''], body: '#ff8c5a', eye: '#22d3ee' }, // fish
  { parts: ['(', E, M, ')'], mouth: ['>', '='], body: '#ffd166', eye: '#22d3ee' }, // chick
]
const SPARKS = ['✦', '✧', '⋆', '·']
const ZZZ = ['z  ', 'zZ ', 'zZz']
const ORBIT = ['◜', '◝', '◞', '◟']

function toSnapshot(u: Pick<SessionUsage, 'context' | 'rateLimits'>, compactAt: number): Snapshot {
  const week = u.rateLimits.find(l => l.kind === 'seven_day')
  return {
    contextTokens: u.context.tokens ?? null,
    contextWindow: u.context.window,
    compactAt,
    weekPercent: week ? week.percentUsed : null,
  }
}

// Where auto-compact fires: the compaction window (autoCompactWindow, or the
// model's limit) less the reserve /context shows as the buffer.
function compactPoint(context: SessionContextUsage) {
  const b = context.breakdown
  if (!b) return context.window
  const buffer = b.categories.filter(c => c.kind === 'buffer').reduce((n, c) => n + c.tokens, 0)
  return b.rawMaxTokens - buffer
}

function mix(a: RGB, b: RGB, t: number): RGB {
  return [0, 1, 2].map(i => Math.round(a[i]! + (b[i]! - a[i]!) * t)) as RGB
}

function along(stops: RGB[], t: number): RGB {
  const x = Math.min(Math.max(t, 0), 1) * (stops.length - 1)
  const i = Math.min(Math.floor(x), stops.length - 2)
  return mix(stops[i]!, stops[i + 1]!, x - i)
}

// Repeatable noise in [0, 1): the same frame always flickers the same way.
function flicker(frame: number) {
  const x = Math.sin(frame * 12.9898) * 43758.5453
  return x - Math.floor(x)
}

function hex([r, g, b]: RGB) {
  return '#' + [r, g, b].map(v => v.toString(16).padStart(2, '0')).join('')
}

function kTokens(n: number) {
  return n >= 1000 ? `${Math.round(n / 1000)}k` : String(n)
}

function freshPick(previous: number | null) {
  const choices = SPECIES.map((_, i) => i).filter(i => i !== previous)
  return choices[Math.floor(Math.random() * choices.length)]!
}

export const register: Register = on => {
  let frame = 0
  let working = false
  let waiting = false // the main turn ended with background work still in flight
  let lastActive = 0
  let ticking: { cancel: () => void } | null = null

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    const u = await $.session.usage({ breakdown: 'summary' })
    await update($, snapshot, () => toSnapshot(u, compactPoint(u.context)))

    const now = await $.clock.now()
    const current = await read($, pet)
    if (current === null || now - current.pickedAt >= PET_LIFETIME_MS) {
      await update($, pet, () => ({ species: freshPick(current?.species ?? null), pickedAt: now }))
    }

    lastActive = now
    ticking?.cancel()
    ticking = $.clock.every(TICK_MS, () => {
      frame += 1
      // Idle or asleep, a redraw a second is enough; while working, every tick.
      if (working || frame % 4 === 0) $.ui.invalidate('ui.render')
    })
    return result
  })

  on('session.measure', async ($, e, next) => {
    const prev = await read($, snapshot)
    const compactAt =
      prev !== null && prev.contextWindow === e.context.window
        ? prev.compactAt
        : compactPoint((await $.session.usage({ breakdown: 'summary' })).context)
    await update($, snapshot, () => toSnapshot(e, compactAt))
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    if (e.agentId === undefined) {
      working = true
      waiting = false
      lastActive = await $.clock.now()
    }
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    if (e.agentId === undefined) await update($, effort, () => e.effort ?? null)
    return yield* next(e)
  })

  on('classic.Stop', async (_$, e, next) => {
    waiting = (e.background_tasks?.length ?? 0) > 0
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) {
      working = false
      lastActive = await $.clock.now()
      // A new pet arrives at most hourly, and only between turns.
      const current = await read($, pet)
      if (current !== null && lastActive - current.pickedAt >= PET_LIFETIME_MS) {
        await update($, pet, () => ({ species: freshPick(current.species), pickedAt: lastActive }))
      }
    }
    return next(e)
  })

  on('ui.render', { component: 'SessionMode' }, async ($, e, next) => {
    const s = await read($, snapshot)
    if (s === null) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    const now = await $.clock.now()
    const ctxPercent = s.contextTokens !== null ? (s.contextTokens / s.compactAt) * 100 : 0

    const mood: Mood =
      ctxPercent >= 85 ? 'stuffed'
      : working ? 'working'
      : waiting ? 'waiting'
      : now - lastActive > SLEEP_AFTER_MS ? 'sleeping'
      : 'idle'

    // Off-turn redraws land once a second, so idle motion is counted in seconds.
    const seconds = Math.floor(frame / 4)
    const isBursting = working || seconds % BURST_EVERY_S < BURST_FOR_S
    const cellsFilled = (percent: number) => (Math.min(Math.max(percent, 0), 100) / 100) * CELLS

    // Context: heights are only the wave's motion; lit cells carry the fill.
    const waveform = (percent: number) => {
      const stops = percent >= 85 ? HOT : CALM
      const filled = cellsFilled(percent)
      const bursts = Math.floor(seconds / BURST_EVERY_S) * BURST_FOR_S + Math.min(seconds % BURST_EVERY_S, BURST_FOR_S)
      const t =
        working ? frame * 0.35
        : mood === 'sleeping' ? 0
        : mood === 'waiting' ? seconds * 0.6
        : bursts * 0.6
      return (
        <Text>
          {Array.from({ length: CELLS }, (_, i) => {
            const height = 0.5 + 0.3 * Math.sin(i * 1.3 + t) + 0.2 * Math.sin(i * 2.7 - t * 0.6)
            const glyph = WAVE[Math.min(Math.floor(Math.max(height, 0) * WAVE.length), WAVE.length - 1)]
            const lit = Math.min(Math.max(filled - i, 0), 1)
            const c = mix(TRACK_RGB, along(stops, i / (CELLS - 1)), lit)
            return <Text key={String(i)} color={hex(c)}>{glyph}</Text>
          })}
        </Text>
      )
    }

    // Weekly: burned cells stay solid; the leading edge smoulders and flickers.
    const ember = (percent: number) => {
      const stops = percent >= 85 ? HOT : CALM
      const filled = cellsFilled(percent)
      const edge = Math.ceil(filled) - 1
      const heat = isBursting && mood !== 'sleeping' ? flicker(frame) * 0.7 : 0
      return (
        <Text>
          {Array.from({ length: CELLS }, (_, i) => {
            const base = along(stops, i / (CELLS - 1))
            const part = filled - i
            const glyph = part <= 0 ? ' ' : part <= 1 / 3 ? '░' : part <= 2 / 3 ? '▒' : part < 1 ? '▓' : '█'
            const c = i === edge ? mix(base, GOLD, heat) : base
            return <Text key={String(i)} color={hex(c)} backgroundColor={TRACK}>{glyph}</Text>
          })}
        </Text>
      )
    }
    const endColor = (percent: number) => hex(along(percent >= 85 ? HOT : CALM, percent / 100))

    const picked = await read($, pet)
    const sp = SPECIES[picked?.species ?? 0]!
    const isBusyFrame = Math.floor(frame / 2) % 2 === 1
    const eye =
      mood === 'sleeping' ? '-'
      : mood === 'stuffed' ? 'o'
      : mood === 'idle' && frame % 20 === 0 ? '-'
      : mood === 'waiting' ? '◦'
      : mood === 'working' && isBusyFrame ? '°'
      : '•'
    const mouth = mood === 'working' && isBusyFrame ? sp.mouth[1] : sp.mouth[0]
    const eyeColor = mood === 'stuffed' ? hex(HOT[2]!) : sp.eye
    const trail =
      mood === 'working' ? ` ${SPARKS[frame % SPARKS.length]} `
      // Off-turn redraws land once a second, so the orbit steps once a second.
      : mood === 'waiting' ? ` ${ORBIT[Math.floor(frame / 4) % ORBIT.length]} `
      : mood === 'sleeping' ? ZZZ[Math.floor(frame / 4) % ZZZ.length]!
      : mood === 'stuffed' ? ' ; '
      : '   '
    const trailColor =
      mood === 'working' ? hex(along([POP, GOLD, POP], (frame % 24) / 24))
      : mood === 'waiting' ? hex(POP)
      : mood === 'stuffed' ? hex(HOT[1]!)
      : 'subtle'
    const isDim = mood === 'sleeping'

    const level = await read($, effort)
    const levelIndex = typeof level === 'string' ? EFFORT_LEVELS.indexOf(level) : -1

    return (
      <Box gap={2}>
        {e.props.modes.length > 0 ? <Text dimColor>{e.props.modes.join(' & ')}</Text> : null}
        {level !== null ? (
          <Text>
            {'🧠 '}
            {levelIndex >= 0
              ? EFFORT_STEPS.map((step, i) => (
                  <Text key={String(i)} color={i <= levelIndex ? hex(along(CALM, (i + 1) / EFFORT_STEPS.length)) : TRACK}>
                    {step}
                  </Text>
                ))
              : null}
            <Text color={hex(GOLD)}>{levelIndex >= 0 ? ` ${EFFORT_LETTERS[levelIndex]}` : String(level)}</Text>
          </Text>
        ) : null}
        {s.contextTokens !== null ? (
          <Box gap={1}>
            {waveform(ctxPercent)}
            <Text color={endColor(ctxPercent)}>{kTokens(s.contextTokens)}</Text>
          </Box>
        ) : null}
        {s.weekPercent !== null ? (
          <Box gap={1}>
            {ember(s.weekPercent)}
            <Text color={endColor(s.weekPercent)}>{`${Math.round(s.weekPercent)}%`}</Text>
          </Box>
        ) : null}
        <Text>
          {sp.parts.map((p, i) =>
            p === E ? <Text key={String(i)} color={eyeColor} bold dimColor={isDim}>{eye}</Text>
            : p === M ? <Text key={String(i)} color={sp.body} dimColor={isDim}>{mouth}</Text>
            : <Text key={String(i)} color={sp.body} bold dimColor={isDim}>{p}</Text>,
          )}
          <Text color={trailColor} dimColor={isDim}>{trail}</Text>
        </Text>
      </Box>
    )
  })
}
