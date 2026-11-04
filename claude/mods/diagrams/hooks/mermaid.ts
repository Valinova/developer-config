// Renders the flowchart subset of Mermaid as box-drawing text.
//
// simplified: layered layout (longest path, one barycenter pass), no edge
// crossing minimisation, edge styles (dotted, thick) drawn as plain lines,
// subgraphs flattened, labels assumed one terminal cell per character.
// upgrade when: diagrams Claude writes come out tangled or misaligned often
// enough to notice.

type Dir = 'LR' | 'TD'
type Shape = 'rect' | 'round' | 'decision' | 'circle'
type Node = { id: string; label: string; shape: Shape }
type Edge = { from: string; to: string; label: string }
type Graph = { dir: Dir; nodes: Map<string, Node>; edges: Edge[] }

/** Wider than this, a diagram is drawn in the other direction if that is narrower. */
const MAX_WIDTH = 100

const NODE_RE =
  /^\s*([A-Za-z0-9_]+)\s*(?:\(\((.*?)\)\)|\[\((.*?)\)\]|\[\[(.*?)\]\]|\[(.*?)\]|\(\[(.*?)\]\)|\((.*?)\)|\{\{(.*?)\}\}|\{(.*?)\}|>(.*?)\])?/
const EDGE_RE =
  /^\s*(?:--\s+([^-|>][^>]*?)\s*-->|-\.\s*([^.]+?)\s*\.->|==\s+([^=]+?)\s*==>|-->|-\.->|==>)\s*(?:\|([^|]*)\|)?/
const SKIP_RE = /^(subgraph|end\b|classDef|class\s|style\s|linkStyle|click\s|direction\s|%%)/

function clean(label: string) {
  return label.replace(/^["']|["']$/g, '').replace(/<br\s*\/?>/gi, ' ').trim()
}

/** Parses a flowchart; `null` for any other diagram or a statement it cannot read. */
export function parse(source: string): Graph | null {
  const lines = source.split(/\n|;/).map(l => l.trim()).filter(Boolean)
  const head = /^(flowchart|graph)\s+(LR|RL|TD|TB|BT)\b/.exec(lines[0] ?? '')
  if (!head) return null
  const dir: Dir = head[2] === 'LR' || head[2] === 'RL' ? 'LR' : 'TD'
  const nodes = new Map<string, Node>()
  const edges: Edge[] = []

  const readGroup = (rest: string): [string[], string] | null => {
    const ids: string[] = []
    for (;;) {
      const m = NODE_RE.exec(rest)
      if (!m) return null
      const id = m[1]!
      const [circle, cyl, sub, rect, stadium, round, hex, decision, flag] = m.slice(2)
      const text = circle ?? cyl ?? sub ?? rect ?? stadium ?? round ?? hex ?? decision ?? flag
      const shape: Shape =
        circle !== undefined ? 'circle'
        : decision !== undefined || hex !== undefined ? 'decision'
        : round !== undefined || stadium !== undefined ? 'round'
        : 'rect'
      const known = nodes.get(id)
      if (text !== undefined || !known) nodes.set(id, { id, label: clean(text ?? id), shape: text !== undefined ? shape : known?.shape ?? 'rect' })
      ids.push(id)
      rest = rest.slice(m[0].length)
      const amp = /^\s*&/.exec(rest)
      if (!amp) return [ids, rest]
      rest = rest.slice(amp[0].length)
    }
  }

  for (const line of lines.slice(1)) {
    if (SKIP_RE.test(line)) continue
    let group = readGroup(line)
    if (!group) return null
    let [from, rest] = group
    while (rest.trim()) {
      const op = EDGE_RE.exec(rest)
      if (!op) return null
      const label = clean(op[1] ?? op[2] ?? op[3] ?? op[4] ?? '')
      group = readGroup(rest.slice(op[0].length))
      if (!group) return null
      const [to, after] = group
      for (const f of from) for (const t of to) {
        if (f === t) return null
        edges.push({ from: f, to: t, label })
      }
      from = to
      rest = after
    }
  }
  return nodes.size > 0 ? { dir, nodes, edges } : null
}

// ── layout ────────────────────────────────────────────────────────────────

type Slot = { id: string; dummy: boolean }
/** `from` may be a dummy slot; `origin` is the node the edge really starts at. */
type Link = { from: string; origin: string; to: string; label: string; up: boolean }

function layer(g: Graph) {
  const order = [...g.nodes.keys()]
  // Break cycles: an edge back to a node still on the DFS stack is laid out reversed.
  const state = new Map<string, 'open' | 'done'>()
  const out = new Map<string, Edge[]>()
  for (const e of g.edges) out.set(e.from, [...(out.get(e.from) ?? []), e])
  const back = new Set<Edge>()
  const visit = (id: string) => {
    state.set(id, 'open')
    for (const e of out.get(id) ?? []) {
      const s = state.get(e.to)
      if (s === 'open') back.add(e)
      else if (s === undefined) visit(e.to)
    }
    state.set(id, 'done')
  }
  for (const id of order) if (!state.has(id)) visit(id)

  const forward = g.edges
    .map(e => (back.has(e) ? { from: e.to, to: e.from, label: e.label, up: true } : { ...e, up: false }))

  const rank = new Map<string, number>(order.map(id => [id, 0]))
  for (let changed = true, guard = 0; changed && guard < order.length + 1; guard++) {
    changed = false
    for (const e of forward) {
      const r = rank.get(e.from)! + 1
      if (r > rank.get(e.to)!) { rank.set(e.to, r); changed = true }
    }
  }

  // Edges spanning layers pass through dummy slots, one per layer crossed.
  const links: Link[] = []
  const layers: Slot[][] = []
  const put = (r: number, slot: Slot) => (layers[r] ??= []).push(slot)
  for (const id of order) put(rank.get(id)!, { id, dummy: false })
  let n = 0
  for (const e of forward) {
    let prev = e.from
    for (let r = rank.get(e.from)! + 1; r < rank.get(e.to)!; r++) {
      const id = `\0${n++}`
      put(r, { id, dummy: true })
      links.push({ from: prev, origin: e.from, to: id, label: '', up: e.up })
      prev = id
    }
    links.push({ from: prev, origin: e.from, to: e.to, label: e.label, up: e.up })
  }

  // One barycenter pass: order each layer by the mean position of its parents.
  for (let r = 1; r < layers.length; r++) {
    const pos = new Map(layers[r - 1]!.map((s, i) => [s.id, i]))
    const bary = (s: Slot, i: number) => {
      const ps = links.filter(l => l.to === s.id).map(l => pos.get(l.from)).filter((p): p is number => p !== undefined)
      return ps.length ? ps.reduce((a, b) => a + b, 0) / ps.length : i
    }
    layers[r] = layers[r]!.map((s, i) => [s, bary(s, i)] as const).sort((a, b) => a[1] - b[1]).map(([s]) => s)
  }
  return { layers: layers.map(l => l ?? []), links }
}

// ── canvas ────────────────────────────────────────────────────────────────

const U = 1, D = 2, L = 4, R = 8
const JOIN: Record<number, string> = {
  [U]: '│', [D]: '│', [U | D]: '│', [L]: '─', [R]: '─', [L | R]: '─',
  [D | R]: '╭', [D | L]: '╮', [U | R]: '╰', [U | L]: '╯',
  [U | D | R]: '├', [U | D | L]: '┤', [D | L | R]: '┬', [U | L | R]: '┴', [U | D | L | R]: '┼',
}

class Canvas {
  text: (string | undefined)[][] = []
  mask: number[][] = []
  set(x: number, y: number, ch: string) {
    ;(this.text[y] ??= [])[x] = ch
  }
  bits(x: number, y: number, b: number) {
    const row = (this.mask[y] ??= [])
    row[x] = (row[x] ?? 0) | b
  }
  free(x: number, y: number) {
    return this.text[y]?.[x] === undefined && !this.mask[y]?.[x]
  }
  hline(y: number, x1: number, x2: number) {
    const [a, b] = x1 < x2 ? [x1, x2] : [x2, x1]
    for (let x = a; x <= b; x++) this.bits(x, y, (x > a ? L : 0) | (x < b ? R : 0))
  }
  vline(x: number, y1: number, y2: number) {
    const [a, b] = y1 < y2 ? [y1, y2] : [y2, y1]
    for (let y = a; y <= b; y++) this.bits(x, y, (y > a ? U : 0) | (y < b ? D : 0))
  }
  write(x: number, y: number, s: string) {
    ;[...s].forEach((ch, i) => this.set(x + i, y, ch))
  }
  box(x: number, y: number, w: number, label: string, shape: Shape) {
    const [tl, tr, bl, br, side] =
      shape === 'rect' ? ['┌', '┐', '└', '┘', '│']
      : shape === 'circle' ? ['╔', '╗', '╚', '╝', '║']
      : ['╭', '╮', '╰', '╯', '│']
    const h = shape === 'circle' ? '═' : '─'
    const inner = shape === 'decision' ? `◇ ${label}` : label
    const pad = w - 2 - [...inner].length
    this.write(x, y, tl + h.repeat(w - 2) + tr)
    this.write(x, y + 1, side + ' '.repeat(Math.floor(pad / 2)) + inner + ' '.repeat(Math.ceil(pad / 2)) + side)
    this.write(x, y + 2, bl + h.repeat(w - 2) + br)
  }
  toString() {
    const rows = Math.max(this.text.length, this.mask.length)
    const out: string[] = []
    for (let y = 0; y < rows; y++) {
      const cols = Math.max(this.text[y]?.length ?? 0, this.mask[y]?.length ?? 0)
      let line = ''
      for (let x = 0; x < cols; x++) line += this.text[y]?.[x] ?? JOIN[this.mask[y]?.[x] ?? 0] ?? ' '
      out.push(line.trimEnd())
    }
    return out.join('\n')
  }
}

const width = (g: Graph, s: Slot) => {
  const n = g.nodes.get(s.id)
  if (!n) return 1
  return [...(n.shape === 'decision' ? `◇ ${n.label}` : n.label)].length + 4
}

const crossingFrom = (slots: Slot[], links: Link[]) => {
  const ids = new Set(slots.map(s => s.id))
  return links.filter(k => ids.has(k.from))
}

/**
 * A gap's shared bus can invent connections between multiple sources and targets.
 * It is safe when every connected group of its links is a star (one source or one
 * target) and no two groups overlap along the bus, which would touch on its one row.
 */
function busIsAmbiguous(crossing: Link[], centre: (id: string) => number) {
  const parent = new Map<string, string>()
  const find = (x: string): string => { const p = parent.get(x) ?? x; if (p === x) return x; const r = find(p); parent.set(x, r); return r }
  for (const k of crossing) parent.set(find('s:' + k.from), find('t:' + k.to))
  const groups = new Map<string, { s: Set<string>; t: Set<string> }>()
  for (const k of crossing) {
    const r = find('s:' + k.from)
    const g = groups.get(r) ?? { s: new Set(), t: new Set() }
    g.s.add(k.from); g.t.add(k.to); groups.set(r, g)
  }
  if ([...groups.values()].some(g => g.s.size > 1 && g.t.size > 1)) return true
  const spans = [...groups.values()]
    .map(g => [...g.s, ...g.t].map(centre))
    .map(at => [Math.min(...at), Math.max(...at)] as const)
    .toSorted((a, b) => a[0] - b[0])
  return spans.some(([start], i) => i > 0 && start <= spans[i - 1]![1])
}

type Span = { x: number; w: number }
type Lane = { sx: number; tx: number; row: number }

/** `k` columns on a slot's edge, spread around its centre; `null` when it has too few. */
function ports({ x, w }: Span, k: number) {
  if (w === 1) return k === 1 ? [x] : null
  const lo = x + 1, hi = x + w - 2, room = hi - lo + 1
  if (k > room) return null
  const step = room >= 2 * k - 1 ? 2 : 1
  const first = Math.max(lo, Math.min(x + Math.floor(w / 2) - Math.floor(((k - 1) * step) / 2), hi - (k - 1) * step))
  return Array.from({ length: k }, (_, i) => first + i * step)
}

/**
 * Gives each link of a gap its own source column, target column and row, so links
 * never share a segment and a `┼` there is only ever a crossing. `null` when a slot
 * has too few columns, or a stem would run into another link's whatever the row order.
 */
function laneRoutes(crossing: Link[], at: Map<string, Span>) {
  const centre = (id: string) => at.get(id)!.x + Math.floor(at.get(id)!.w / 2)
  const by = (key: (k: Link) => string) => {
    const out = new Map<string, Link[]>()
    for (const k of crossing) out.set(key(k), [...(out.get(key(k)) ?? []), k])
    return out
  }
  const sx = new Map<Link, number>(), tx = new Map<Link, number>()
  for (const [id, out] of by(k => k.from)) {
    const cols = ports(at.get(id)!, out.length)
    if (!cols) return null
    out.toSorted((a, b) => centre(a.to) - centre(b.to)).forEach((k, i) => sx.set(k, cols[i]!))
  }
  for (const [id, into] of by(k => k.to)) {
    const span = at.get(id)!
    const only = into.length === 1 ? sx.get(into[0]!)! : null
    // A lone link drops straight in when its source column lands on the slot.
    if (only !== null && only > span.x && only < span.x + span.w - 1) { tx.set(into[0]!, only); continue }
    const cols = ports(span, into.length)
    if (!cols) return null
    into.toSorted((a, b) => sx.get(a)! - sx.get(b)!).forEach((k, i) => tx.set(k, cols[i]!))
  }
  // A source stem sharing a column with another link's target stem must end above it.
  const bent = crossing.filter(k => sx.get(k) !== tx.get(k)).toSorted((a, b) => sx.get(a)! - sx.get(b)!)
  const ordered: Link[] = []
  while (ordered.length < bent.length) {
    const next = bent.find(k => !ordered.includes(k)
      && !bent.some(o => o !== k && !ordered.includes(o) && sx.get(o) === tx.get(k)))
    if (!next) return null
    ordered.push(next)
  }
  const routes = new Map<Link, Lane>(crossing.map(k => [k, { sx: sx.get(k)!, tx: tx.get(k)!, row: Math.max(0, ordered.indexOf(k)) }]))
  return { routes, rows: Math.max(1, ordered.length) }
}

function drawTD(g: Graph, layers: Slot[][], links: Link[], spill: string[]) {
  const c = new Canvas()
  const at = new Map<string, { x: number; y: number; w: number }>()
  const rowWidth = (l: Slot[]) => l.reduce((a, s) => a + width(g, s), 0) + Math.max(l.length - 1, 0) * 3
  const widest = Math.max(...layers.map(rowWidth))
  layers.forEach(l => {
    let x = Math.floor((widest - rowWidth(l)) / 2)
    for (const s of l) {
      at.set(s.id, { x, y: 0, w: width(g, s) })
      x += width(g, s) + 3
    }
  })
  const lanes = new Map<Link, Lane>()
  const laneRows: number[] = []
  const centre = (id: string) => at.get(id)!.x + Math.floor(at.get(id)!.w / 2)
  let y = 0
  for (const l of layers) {
    for (const s of l) at.get(s.id)!.y = y
    const crossing = crossingFrom(l, links)
    const routed = busIsAmbiguous(crossing, centre) ? laneRoutes(crossing, at) : undefined
    if (routed === null) return null
    routed?.routes.forEach((lane, k) => lanes.set(k, lane))
    if (routed) for (let row = 0; row < routed.rows; row++) laneRows.push(y + 4 + row)
    // Under a layer, a bus gap holds an exit, a forward bus, a loop-back bus and arrows; a lane gap one row per bent link.
    y += routed ? routed.rows + 5 : 7
  }
  for (const l of layers) for (const s of l) {
    const p = at.get(s.id)!
    const n = g.nodes.get(s.id)
    if (n) c.box(p.x, p.y, p.w, n.label, n.shape)
    else c.vline(p.x, p.y, p.y + 2)
  }
  for (const k of links) {
    const a = at.get(k.from)!, b = at.get(k.to)!
    const lane = lanes.get(k)
    // An edge drawn against the flow (a loop back) leaves from its own port, so
    // its ▲ never sits on the junction the forward edges share.
    const port = k.up && g.nodes.has(k.from) ? Math.min(2, Math.floor(a.w / 2) - 2) : 0
    const sx = lane?.sx ?? a.x + Math.floor(a.w / 2) + port, tx = lane?.tx ?? b.x + Math.floor(b.w / 2)
    // Gap rows under a layer: y0 exit, y1 this link's bus or lane, y2 arrows.
    const y0 = a.y + 3, y1 = lane ? y0 + 1 + lane.row : a.y + (k.up ? 5 : 4), y2 = b.y - 1
    c.vline(sx, y0 - (g.nodes.has(k.from) ? 0 : 1), y1)
    c.hline(y1, sx, tx)
    c.vline(tx, y1, y2 + (g.nodes.has(k.to) ? 0 : 1))
    if (g.nodes.has(k.from)) c.set(sx, a.y + 2, '┬')
    if (k.up && g.nodes.has(k.from)) c.set(sx, y0, '▲')
    if (!k.up && g.nodes.has(k.to)) c.set(tx, y2, '▼')
  }
  // Lanes never join, so a crossing there passes behind and `┼` always means a real junction.
  for (const row of laneRows) c.mask[row]?.forEach((bits, x) => { if (bits === (U | D | L | R)) c.set(x, row, '│') })
  // Labels must see every edge and arrow before choosing a free position.
  for (const k of links) {
    if (k.label) {
      const b = at.get(k.to)!
      const lx = (lanes.get(k)?.tx ?? b.x + Math.floor(b.w / 2)) + 2, y2 = b.y - 1
      const fits = [...k.label].every((_, i) => c.free(lx + i, y2)) && c.free(lx - 1, y2)
      if (fits) c.write(lx, y2, k.label)
      else spill.push(`${k.origin} → ${k.to}: ${k.label}`)
    }
  }
  return c.toString()
}

function drawLR(g: Graph, layers: Slot[][], links: Link[], spill: string[]) {
  const c = new Canvas()
  const at = new Map<string, { x: number; y: number; w: number; h: number }>()
  const colWidth = layers.map(l => Math.max(...l.map(s => width(g, s)), 1))
  const gapAfter = layers.map((_, r) => {
    const labels = links.filter(k => layers[r]!.some(s => s.id === k.from)).map(k => [...k.label].length)
    return Math.max(6, Math.max(0, ...labels) + 6)
  })
  const colHeight = (l: Slot[]) => l.reduce((a, s) => a + (g.nodes.has(s.id) ? 3 : 1), 0) + Math.max(l.length - 1, 0)
  const tallest = Math.max(...layers.map(colHeight))
  let x = 0
  layers.forEach((l, r) => {
    let y = Math.floor((tallest - colHeight(l)) / 2)
    for (const s of l) {
      const h = g.nodes.has(s.id) ? 3 : 1
      at.set(s.id, { x, y, w: colWidth[r]!, h })
      y += h + 1
    }
    x += colWidth[r]! + gapAfter[r]!
  })
  // simplified: only top-down has lanes, since a sideways box has one row to leave from. upgrade when: an LR drawing turning top-down reads worse often enough to notice.
  const centre = (id: string) => at.get(id)!.y + Math.floor(at.get(id)!.h / 2)
  if (layers.some(l => busIsAmbiguous(crossingFrom(l, links), centre))) return null
  for (const [id, p] of at) {
    const n = g.nodes.get(id)
    if (n) c.box(p.x, p.y, p.w, n.label, n.shape)
    else c.hline(p.y, p.x, p.x + p.w - 1)
  }
  for (const k of links) {
    const a = at.get(k.from)!, b = at.get(k.to)!
    const sy = a.y + Math.floor(a.h / 2), ty = b.y + Math.floor(b.h / 2)
    const x0 = a.x + a.w, bus = x0 + 1, x1 = b.x - 1
    c.hline(sy, x0 - (g.nodes.has(k.from) ? 0 : 1), bus)
    c.vline(bus, sy, ty)
    c.hline(ty, bus, x1 + (g.nodes.has(k.to) ? 0 : 1))
    if (g.nodes.has(k.from)) c.set(a.x + a.w - 1, sy, '├')
    if (k.up && g.nodes.has(k.from)) c.set(x0, sy, '◀')
    if (!k.up && g.nodes.has(k.to)) c.set(x1, ty, '▶')
    if (k.label) {
      const lx = bus + 2
      const room = x1 - 1 - lx
      if ([...k.label].length <= room && c.text[ty - 1]?.slice(lx, lx + k.label.length).every(ch => ch === undefined) !== false) {
        c.write(lx, ty - 1, k.label)
      } else spill.push(`${k.origin} → ${k.to}: ${k.label}`)
    }
  }
  return c.toString()
}

function draw(g: Graph, dir: Dir) {
  const { layers, links } = layer(g)
  const spill: string[] = []
  const art = dir === 'TD' ? drawTD(g, layers, links, spill) : drawLR(g, layers, links, spill)
  if (art === null) return null
  const label = (id: string) => g.nodes.get(id)?.label ?? id
  const notes = spill.map(s => s.replace(/^(\S+) → (\S+):/, (_, a: string, b: string) => `${label(a)} → ${label(b)}:`))
  return notes.length ? `${art}\n\n${notes.join('\n')}` : art
}

const widthOf = (art: string) => Math.max(...art.split('\n').map(l => [...l].length))

/** Draws a parsed flowchart, turned to the other direction when that fits and this does not. */
export function render(g: Graph) {
  const art = draw(g, g.dir)
  if (art === null) return g.dir === 'LR' ? draw(g, 'TD') : null
  if (widthOf(art) <= MAX_WIDTH) return art
  const turned = draw(g, g.dir === 'LR' ? 'TD' : 'LR')
  return turned !== null && widthOf(turned) < widthOf(art) ? turned : art
}

/** Replaces each closed ```mermaid flowchart block in markdown with its drawing. */
export function renderMarkdown(text: string) {
  return text.replace(/```mermaid[ \t]*\n([\s\S]*?)\n[ \t]*```/g, (block, src: string) => {
    const g = parse(src)
    const art = g && render(g)
    return art === null ? block : '```\n' + art + '\n```'
  })
}
