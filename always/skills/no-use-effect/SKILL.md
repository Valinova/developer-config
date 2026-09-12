---
name: no-use-effect
description: Enforces the repository's no-useEffect policy when writing, refactoring, or reviewing React code, especially when effects derive state, fetch data, react to user actions, or reset state from props. Use for React changes involving useEffect or when the user explicitly invokes "no use effect".
---

# No useEffect

Never call `useEffect` directly without first exhausting the repository's preferred alternatives. Check project documentation for a stricter local policy.

| Instead of `useEffect` for... | Use |
|---|---|
| Deriving state from state or props | Inline computation or `useMemo` |
| Fetching data | Server actions, `useQuery`, loaders, or the project's data layer |
| Responding to user actions | Event handlers |
| One-time external synchronization | A dedicated mount hook when the project provides one |
| Resetting state when identity changes | A `key` prop on the parent |

## Decision Process

1. If the effect derives state, compute the value during render or with `useMemo`.
2. If it fetches data, use the project's data-fetching pattern.
3. If it responds to a user action through a flag, move the work into the event handler.
4. If it synchronizes once with an external system, use the project's mount or subscription abstraction.
5. If it resets state when an ID or key changes, force a remount with the parent's `key`.
6. If none apply, treat it as a possible genuine effect and document why it must synchronize with an external system.

## Common Patterns

Derive values directly instead of synchronizing store-derived state:

```tsx
// Avoid
const items = useStore((state) => state.items)
useEffect(() => setActive(items[0]?.id), [items])

// Prefer
const items = useStore((state) => state.items)
const active =
  selectedId && items.some((item) => item.id === selectedId)
    ? selectedId
    : items[0]?.id
```

Use the project's editable-field abstraction instead of focus-guarded effects:

```tsx
// Avoid
useEffect(() => {
  if (!focused) setLocal(storeValue)
}, [storeValue, focused])

// Prefer
const { displayValue, handlers } = useEditableField(storeValue, onChange)
```

After refactoring, run type checking and linting and confirm that observable component behavior is unchanged.
