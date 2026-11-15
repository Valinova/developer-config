// Records which worker ran each test file and in what order (LEAKS_ORDER_OUT), so a failure
// under a shuffled run can be replayed with exactly the files that preceded it in its worker.
import { writeFileSync } from 'node:fs'
const rows = []
let started = 0
export default class {
  onTestModuleStart(module) { module.__seq = started++ }
  onTestModuleEnd(module) {
    const diagnostic = module.diagnostic()
    rows.push({ file: module.relativeModuleId ?? module.moduleId, worker: diagnostic.concurrencyId ?? diagnostic.workerId, seq: module.__seq, ok: module.ok() })
  }
  onTestRunEnd() { writeFileSync(process.env.LEAKS_ORDER_OUT, JSON.stringify(rows)) }
}
