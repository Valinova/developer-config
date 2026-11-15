#!/usr/bin/env node
// Where does a GitHub Actions workflow spend its time? Run from the repo root (uses the gh CLI).
//   node run-timings.mjs "<workflow name or file>" [runs=150]
// Per job: time waiting for a runner, then every step, at p50 and p95 over the last runs that
// finished. Per run: wall time from trigger to last job, and summed job time (what is billed).
// Sort the steps into setup and real work yourself; the names differ per repo.
import { execFileSync } from 'node:child_process'

const [workflow, limit = '150'] = process.argv.slice(2)
if (!workflow) { console.error('usage: node run-timings.mjs "<workflow name or file>" [runs=150]'); process.exit(2) }
const gh = (...args) => JSON.parse(execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 }))
const seconds = (from, to) => (Date.parse(to) - Date.parse(from)) / 1000
const percentile = (values, p) => { const sorted = [...values].sort((a, b) => a - b); return sorted[Math.min(sorted.length - 1, Math.ceil(p * sorted.length) - 1)] }
const cell = values => values.length ? `${percentile(values, 0.5).toFixed(0).padStart(5)}s ${percentile(values, 0.95).toFixed(0).padStart(5)}s` : '      -      -'

const runs = gh('run', 'list', '--workflow', workflow, '--limit', limit, '--json', 'databaseId,conclusion,createdAt,status')
  .filter(run => run.status === 'completed' && run.conclusion !== 'cancelled' && run.conclusion !== 'skipped')
const conclusions = {}
const jobs = new Map()
const wall = [], billed = []
for (const run of runs) {
  conclusions[run.conclusion] = (conclusions[run.conclusion] ?? 0) + 1
  const finished = gh('api', `repos/{owner}/{repo}/actions/runs/${run.databaseId}/jobs?per_page=100`).jobs
    .filter(job => job.started_at && job.completed_at && job.conclusion !== 'cancelled' && job.conclusion !== 'skipped')
  if (!finished.length) continue
  wall.push(seconds(run.createdAt, finished.map(job => job.completed_at).sort().at(-1)))
  billed.push(finished.reduce((sum, job) => sum + seconds(job.started_at, job.completed_at), 0))
  for (const job of finished) {
    const entry = jobs.get(job.name) ?? { waiting: [], total: [], steps: new Map() }
    jobs.set(job.name, entry)
    entry.waiting.push(Math.max(0, seconds(job.created_at, job.started_at)))
    entry.total.push(seconds(job.started_at, job.completed_at))
    for (const step of job.steps ?? []) {
      if (!step.started_at || !step.completed_at || step.conclusion === 'skipped') continue
      if (!entry.steps.has(step.name)) entry.steps.set(step.name, [])
      entry.steps.get(step.name).push(seconds(step.started_at, step.completed_at))
    }
  }
}

console.log(`${workflow}: ${wall.length} finished runs  ${Object.entries(conclusions).map(([k, v]) => `${k} ${v}`).join(', ')}`)
console.log(`${'trigger to last job done'.padEnd(46)}${cell(wall)}   (p50, p95)`)
console.log(`${'summed job time per run'.padEnd(46)}${cell(billed)}`)
for (const [name, entry] of [...jobs].sort((a, b) => percentile(b[1].total, 0.5) - percentile(a[1].total, 0.5))) {
  console.log(`\n${name}  (${entry.total.length} jobs)`)
  console.log(`  ${'waiting for a runner'.padEnd(44)}${cell(entry.waiting)}`)
  console.log(`  ${'whole job'.padEnd(44)}${cell(entry.total)}`)
  for (const [step, values] of entry.steps) console.log(`    ${step.slice(0, 42).padEnd(42)}${cell(values)}`)
}
