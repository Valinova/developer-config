/** Tokens at which auto-compact fires (`at`), the gauge's full mark, counted for this context `window`. */
export type CompactionPoint = { window: number; at: number }

/** Which of the mod's pets is shown, and when it was picked (`$.clock.now()` ms). */
export type Pet = { species: number; pickedAt: number }

declare module 'claude-code' {
  interface PluginState {
    'usage-meters': { compaction: CompactionPoint | null; pet: Pet | null; effort: string | number | null }
  }
}
