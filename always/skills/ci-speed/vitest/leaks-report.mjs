// Reads what leaks.sh wrote. Not run directly.
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
const [mode, file, ...rest] = process.argv.slice(2)
const tally = items => { const counts = {}; for (const item of items) counts[item] = (counts[item] ?? 0) + 1; return Object.entries(counts).sort((a, b) => b[1] - a[1]) }
const unique = items => [...new Set(items)]

if (mode === 'census') {
  if (!existsSync(file)) { console.log('No file left anything behind.'); process.exit(0) }
  const rows = readFileSync(file, 'utf8').trim().split('\n').map(line => JSON.parse(line))
  const print = (title, entries, examples) => {
    console.log(`\n${title}`)
    for (const [key, count] of entries) console.log(`  ${String(count).padStart(4)}  ${key}${count <= 3 && examples ? `   <- ${examples(key).join(', ')}` : ''}`)
  }
  const source = text => text.replace(/^set\w+\(\d+ms\) /, '').split(' < ')[0].replace(/:\d+:\d+$/, '')
  const timers = rows.filter(row => row.timers.length), events = rows.filter(row => row.events.length)
  console.log(`\nTest files that end with a timer pending: ${timers.length}; with other work still running: ${events.length}`)
  print('Pending timers, by where they were scheduled (files)', tally(timers.flatMap(row => unique(row.timers.map(source)))).slice(0, 15))
  console.log('\nWork still running after the file ended')
  for (const row of events) { console.log(`  ${row.file}`); for (const event of unique(row.events.map(event => event.slice(0, 200))).slice(0, 3)) console.log(`      ${event}`) }
  // Globals a library adds once (double-underscore names, React's act flag) are not a test's doing.
  const state = rows.map(row => ({ file: row.file, state: row.state.filter(entry => !/^global\+:(__|IS_REACT_ACT_ENVIRONMENT)/.test(entry)) })).filter(row => row.state.length)
  print('Worker state left changed (files)', tally(state.flatMap(row => unique(row.state))).slice(0, 40), key => state.filter(row => row.state.includes(key)).map(row => row.file))
}

const precedingInWorker = (rows, failed) => rows.filter(row => row.worker === failed.worker && row.seq < failed.seq).sort((a, b) => a.seq - b.seq)

if (mode === 'sweep') {
  const [run, code, summary] = rest
  const rows = JSON.parse(readFileSync(file, 'utf8'))
  const failed = rows.filter(row => !row.ok)
  console.log(`run ${run} exit ${code} files ${rows.length} failed ${failed.length} |${summary}`)
  for (const row of failed) console.log(`  FAIL ${row.file} (after ${precedingInWorker(rows, row).length} files in its worker)`)
}

if (mode === 'sequences') {
  const [prefix] = rest
  const rows = JSON.parse(readFileSync(file, 'utf8'))
  const failed = rows.filter(row => !row.ok)
  if (!failed.length) { console.error('That run had no failing file.'); process.exit(1) }
  failed.forEach((row, index) => writeFileSync(`${prefix}-${index}.seq`, [...precedingInWorker(rows, row), row].map(entry => entry.file).join('\n') + '\n'))
}
