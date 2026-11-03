import type { Register } from 'claude-code'

import { renderMarkdown } from './mermaid'

// The rule lives with the renderer: only a session that draws these blocks is
// asked to write them.
const DIRECTIVE = {
  id: 'diagrams:directive',
  scope: 'session',
  text: [
    '# Diagrams',
    'When a flow, architecture, state machine, dependency or set of options reads better as a picture, lead with a diagram written as a ```mermaid block using `flowchart LR` or `flowchart TD`.',
    'The terminal draws these blocks as box diagrams. Supported: nodes `A[Label]`, `A(Label)`, `A{Decision}`, `A((Label))`; edges `-->`, `-.->`, `==>`, labelled `-->|text|`; chains `A --> B --> C`; `&` groups.',
    'Other Mermaid diagram types (sequence, state, class, gantt) are shown as raw text: draw those as plain ASCII instead.',
    'Keep labels short (under ~30 characters) and diagrams under ~12 nodes; prefer `TD` when labels are long.',
  ].join('\n'),
} as const

export const register: Register = on => {
  on('prompt.compose', async ($, e, next) => {
    const { sections } = await next(e)
    return { sections: [...sections, DIRECTIVE] }
  })

  on('ui.render', { component: 'AssistantMessage' }, ($, e, next) => {
    const text = renderMarkdown(e.props.text)
    return text === e.props.text ? next(e) : next({ ...e, props: { ...e.props, text } })
  })
}
