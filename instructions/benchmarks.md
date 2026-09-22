# Benchmarks log

Data behind the effort rule in `model-selection.md` "Effort". Not loaded;
read it when re-tuning the rule, and append new benchmarks as rows.

**Knees:** Opus 5.5 at `medium` (repo code) and `high` (agentic/terminal);
Sol at `high`; Astra gains from `medium` to `high` and nothing past it; Fable
gains little past `high`. No family earns `xhigh`: `high` is the ceiling.

**Caveats.** Mostly vendor charts. Costs are API list prices per task, not
subscription quota, so read them as relative only. Effort labels are
inferred from dot order (low → max) where a chart doesn't label them.
Values read off images are ±0.5. Cells are `score @ $cost`.

## Opus 5.5 System Card summary (Sep 2026, p.174)

Max effort unless noted; mean of 5 trials; Claude in Claude Code, GPT in
Codex CLI.

| Eval | Opus 5.5 | Opus 5 | Fable 5.1 | GPT-6 Astra |
|---|---|---|---|---|
| SWE-bench Pro | 89.9 | 79.2 | 81.2 | – |
| SWE-bench Multilingual | 93.9 | 89.5 | 89.1 | – |
| SWE-bench Multimodal | 61.4 | 59.4 | 54.7 | – |
| FrontierCode v1.1 Main | 54.4 | 48.0 | 50.3 | 53.3 |
| Terminal-Bench 4.0 (Opus 5.5 at xhigh) | 66.4 | 52.3 | 55.8 | 57.9 (high) |
| Terminal-Bench-Science 0.1 | 58.7 | 29.0 | 52.6 | 64.6 |
| FrontierSWE v2 (≈20h tasks) | 62.3 | – | 56.3 | 65.5 |
| ProgramBench | 91.2 | 85.4 | 87.6 | – |
| DeepSWE v1.1 | 74.2 | – | – | – |

## FrontierCode 1.1 Main (Anthropic launch chart; Cognition benchmark)

Grades merge-readiness against a maintainer rubric; penalizes out-of-scope
changes, which is why scores fall above `medium` on some models.

| Model | low | medium | high | xhigh | max |
|---|---|---|---|---|---|
| Opus 5.5 | 47.3 @ $0.4 | **54.6 @ $0.8** | 54.0 @ $1.1 | 51.4 @ $2.2 | 54.4 @ $6 |
| Opus 5 | 42.0 @ $2.7 | 53.4 @ $4.8 | 48.0 @ $7.5 | 43.6 @ $9 | 48.0 @ $13 |
| Fable 5.1 | 52.8 @ $2.5 | 50.9 @ $3.2 | 50.4 @ $5.2 | 48.7 @ $9 | 50.3 @ $13 |
| GPT-6 Astra | 45.3 @ $1.6 | 48.8 @ $2.3 | 51.0 @ $2.9 | 50.6 @ $3.1 | 53.3 @ $4.3 |
| GPT-5.6 Sol | 35.5 @ $1.7 | 40.0 @ $2.4 | 45.0 @ $3.2 | 46.8 @ $3.8 | 47.5 @ $4.6 |

## FrontierCode 1.1 Extended (Cognition chart)

| Model | low | medium | high | xhigh | max |
|---|---|---|---|---|---|
| Opus 5.5 | 60.3 @ $0.35 | **65.3 @ $0.67** | 65.2 @ $0.90 | 63.6 @ $1.85 | 63.6 @ $5.30 |
| GPT-6 Astra | 57.4 @ $1.50 | 60.2 @ $2.10 | 63.1 @ $2.60 | 62.1 @ $2.85 | 64.5 @ $3.90 |
| GPT-6 Sol | 50.5 @ $0.38 | 57.1 @ $0.66 | **59.6 @ $0.87** | 59.1 @ $1.11 | 60.7 @ $1.65 |
| GPT-6 Luna | 39 @ $0.02 | 50.1 @ $0.04 | 51.4 @ $0.06 | ~56 @ $0.08 | – |
| GPT-5.6 Sol | 50.0 @ $1.65 | 54.7 @ $2.30 | 58.7 @ $2.90 | 60.0 @ $3.45 | 60.6 @ $4.25 |
| SWE-2 (3 levels) | 56.5 @ $0.30 | 60.1 @ $0.63 | 62.5 @ $0.93 | – | – |

## Terminal-Bench 4.0 (Anthropic launch chart)

66 long terminal tasks, 8h timeout; rewards persistence and recovery.

| Model | low | medium | high | xhigh | max |
|---|---|---|---|---|---|
| Opus 5.5 | 38.5 @ $1.5 | 57.5 @ $3.0 | **64.3 @ $3.9** | 66.5 @ $7.3 | 65.0 @ $11 |
| GPT-6 Astra | 49.7 @ $5.0 | 54.0 @ $6.2 | 58.0 @ $7.2 | 57.6 @ $7.6 | 56.8 @ $10.5 |
| Fable 5.1 | 40.3 @ $5.7 | 43.3 @ $7.8 | 49.4 @ $10.5 | 51.3 @ $16 | 55.8 @ $19.5 |
| Opus 5 | 28.7 @ $4.2 | 41.2 @ $7.2 | 47.0 @ $10.5 | 50.5 @ $13.5 | 52.3 @ $16 |
| GPT-5.6 Sol | 8 @ $1.5 | 21 @ $2.7 | 26 @ $4.3 | 28.6 @ $5.4 | 37.4 @ $8 |

## CursorBench 4.0 (Cursor production harness, updated chart)

| Model | low | medium | high | xhigh | max |
|---|---|---|---|---|---|
| Opus 5.5 | 43.7 @ $1.2 | 52.5 @ $2.9 | **56.0 @ $4.0** | 56.0 @ $7.0 | 57.8 @ $13.5 |
| Fable 5.1 | 45.0 @ $5.4 | 46.8 @ $7.2 | **49.2 @ $9.0** | 51.6 @ $13 | 51.8 @ $17.3 |
| Grok 4.7 (4 levels) | 33.0 @ $1.7 | 41.5 @ $3.5 | 43.8 @ $4.5 | 46.3 @ $6.0 | – |
| GPT-5.6 Sol | 24.5 @ $0.9 | 31.0 @ $1.8 | 35.7 @ $2.9 | 37.7 @ $4.4 | 41.7 @ $8.2 |
| Opus 5 (card, max only) | – | – | – | – | 46.6 @ $11.95 |

## DeepSWE (OpenAI chart)

113 long-horizon SWE tasks written from scratch to avoid contamination.

| Model | low | medium | high | xhigh | max |
|---|---|---|---|---|---|
| GPT-6 Astra | 67 @ $1.5 | **73 @ $3.3** | 73.5 @ $4.0 | 74 @ $4.5 | 73.5 @ $6.5 |
| GPT-6 Sol | 37 @ $0.17 | 56.5 @ $0.35 | **65.5 @ $0.60** | 66.5 @ $1.0 | 69.5 @ $2.6 |
| GPT-6 Luna | 2.5 @ $0.005 | 44.5 @ $0.05 | 59 @ $0.08 | 61.5 @ $0.11 | 66.5 @ $0.20 |
| Opus 5 | 58 @ $1.7 | 69 @ $2.8 | 72.5 @ $5.5 | 73 @ $8 | 73.5 @ $11 |
| Fable 5 | 59.5 @ $3.2 | 65.5 @ $6 | 68.5 @ $8 | 70 @ $10 | 69.5 @ $20 |
| Opus 5.5 (card, max only) | – | – | – | – | 74.2 |

## Artificial Analysis Intelligence Index v4.3 (general, not coding-only)

10 evals incl. Terminal-Bench 4.0 and SciCode. Max effort unless noted;
cost is AA's weighted cost per index task.

| Model | Index | ≈ cost / task |
|---|---|---|
| Opus 5.5 | 58 | $6 |
| Fable 5.1 | 53 | $8 |
| GPT-6 Astra | 53 | $3.5 |
| Opus 5 | 51 | $6 |
| GPT-6 Sol | 48 | $1.05 |
| GPT-5.6 Sol | 47 | $2 |
| Grok 4.7 (xhigh) | 46 | – |
| DeepSeek V4.1 Flash | 39 | – |
| GPT-6 Luna | 37 | $0.07 |

Opus 5.5 sits on AA's cost/score Pareto line from ≈ $1.2 per task upward;
Astra does not.

## Steps past `high` (derived from the tables above)

| Step | FC Main | FC Ext. | Terminal-Bench | CursorBench | DeepSWE |
|---|---|---|---|---|---|
| Astra high → xhigh | −0.4 | −1.0 | −0.4 | – | +0.5 |
| Opus 5.5 high → xhigh | −2.6 | −1.6 | +2.2 (≈1.9x) | 0.0 | – |
| Fable 5.1 high → xhigh | −1.7 | – | +1.9 (≈1.5x) | +2.4 (≈1.4x) | – |
| Sol high → xhigh | – | −0.5 | – | – | +1.0 (+$0.40) |
| Sol high → max | – | +1.1 (+$0.78) | – | – | +4.0 (+$2.00) |
| Sol high → Astra medium | – | +0.6 (+$1.23) | – | – | +7.5 (+$2.70) |
| Luna xhigh → max | – | – | – | – | +5.0 (+$0.09) |

Sol and Luna gain a little above `high` at small absolute cost — the one
caveat to the `high` ceiling. It isn't a rule: escalating to Astra `medium`
matches or beats Sol `max` for a little more, and Luna is override-only.
