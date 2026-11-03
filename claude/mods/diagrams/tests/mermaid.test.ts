import { expect, test } from 'bun:test'

import { renderMarkdown } from '../hooks/mermaid'

const block = (src: string) => '```mermaid\n' + src + '\n```'

// The renderer is the mod's one piece of logic; the hooks only hand it the
// reply's text. Each case is a way a drawn reply goes wrong.
test('a flowchart block is replaced by a box drawing with every label', () => {
  const out = renderMarkdown(`Before\n${block('flowchart TD\n  A[Start] --> B{Ready?}\n  B -->|yes| C(Ship)')}\nAfter`)
  expect(out).not.toContain('```mermaid')
  for (const label of ['Start', 'Ready?', 'Ship', 'yes']) expect(out).toContain(label)
  expect(out.startsWith('Before\n```\n')).toBe(true)
  expect(out.endsWith('\n```\nAfter')).toBe(true)
})

const untouched = [
  ['another diagram type', block('sequenceDiagram\n  A->>B: hi')],
  ['a block still streaming in', '```mermaid\nflowchart LR\n  A --> B'],
  ['a statement the parser cannot read', block('flowchart LR\n  A --> ')],
  // These edges used to disappear or become one-way arrows; ordinary paths did not catch them.
  ['a self-loop', block('flowchart LR\n  A --> A')],
  ['a self-loop in a group', block('flowchart LR\n  A --> A & B')],
  ['an undirected edge', block('flowchart LR\n  A --- B')],
  ['a bidirectional edge', block('flowchart LR\n  A <--> B')],
  ['an undirected dotted edge', block('flowchart LR\n  A -.- B')],
  ['an undirected thick edge', block('flowchart LR\n  A === B')],
  ['a circle-ended edge', block('flowchart LR\n  A --o B')],
  ['a cross-ended edge', block('flowchart LR\n  A --x B')],
  ['an invisible edge', block('flowchart LR\n  A ~~~ B')],
] as const
for (const [name, text] of untouched) {
  test(`${name} is left as written`, () => {
    expect(renderMarkdown(text)).toBe(text)
  })
}

// Shared buses used to turn these different edge sets into the same connections.
for (const dir of ['LR', 'TD']) for (const edges of [
  'A --> C; A --> D; B --> D',
  'A --> C; B --> C; B --> D',
  'A --> D; B --> C',
]) {
  test(`${dir} preserves Mermaid for a boundary with multiple sources and targets: ${edges}`, () => {
    const text = block(`flowchart ${dir}\nA[Alpha]; B[Bee]; C[Cee]; D[Dee]\n${edges}`)
    expect(renderMarkdown(text)).toBe(text)
  })
}

// Straight paths and ordinary fans remain supported when ambiguous buses fall back.
for (const dir of ['LR', 'TD']) for (const edges of [
  'A[Start] --> B[End]',
  'A[Start] --> B[End] & C[Other]',
  'A[Start] & B[Other] --> C[End]',
]) {
  test(`${dir} draws straight paths and fans without false crossings: ${edges}`, () => {
    const out = renderMarkdown(block(`flowchart ${dir}\n${edges}`))
    expect(out).not.toContain('```mermaid')
    expect(out).not.toContain('┼')
    for (const label of ['Start', 'End']) expect(out).toContain(label)
  })
}

test('later TD edges cannot overwrite an earlier edge label', () => {
  // A long first label used to occupy the second edge's arrow cell.
  const out = renderMarkdown(block('flowchart TD\nA[Start] -->|a very long label| B[End]\nA -->|z| C[Other]'))
  expect(out).not.toContain('```mermaid')
  expect(out).toContain('a very long label')
  expect(out).toMatch(/\bz\b/)
  expect((out.match(/▼/g) ?? []).length).toBe(2)
})

test('a loop back leaves its node from its own port, not the forward junction', () => {
  const out = renderMarkdown(block('flowchart TD\n  A[Start] --> B{In?}\n  B -->|yes| C[Home]\n  B -->|no| D[Login]\n  D --> B'))
  const lines = out.split('\n')
  const bottom = lines.findIndex(l => l.includes('╰') && l.includes('┬'))
  // Two exits on the decision's bottom edge: the forward one and the loop's ▲ below its own.
  expect((lines[bottom]!.match(/┬/g) ?? []).length).toBe(2)
  const up = lines[bottom + 1]!.indexOf('▲')
  expect(up).toBeGreaterThan(-1)
  expect(lines[bottom]![up]).toBe('┬')
})

test('a drawing wider than the terminal budget turns to the narrower direction', () => {
  const long = (n: number) => `N${n}[${'step number ' + n + ' of a long pipeline'}]`
  const src = `flowchart LR\n  ${[1, 2, 3, 4].map(long).join(' --> ')}`
  const art = renderMarkdown(block(src))
  const widest = Math.max(...art.split('\n').map(l => [...l].length))
  expect(widest).toBeLessThanOrEqual(100)
})
