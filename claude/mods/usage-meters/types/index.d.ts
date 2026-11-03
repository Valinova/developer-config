export type Snapshot = {
  contextTokens: number | null
  contextWindow: number
  /** Tokens at which auto-compact fires; the gauge fills toward this. */
  compactAt: number
  weekPercent: number | null
}

/** Which of the mod's pets is shown, and when it was picked (`$.clock.now()` ms). */
export type Pet = { species: number; pickedAt: number }

declare module 'claude-code' {
  interface PluginState {
    'usage-meters': { snapshot: Shaped<Snapshot | null>; pet: Pet | null; effort: string | number | null }
  }
}
