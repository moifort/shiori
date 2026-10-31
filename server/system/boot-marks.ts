import { createLogger } from '~/system/logger'

const logger = createLogger('boot')

const uptimeMs = () => Math.round(process.uptime() * 1000)

// Evaluated with the first line of our bundle, so this first figure is what ran
// before it: Node, the Functions Framework and every external package imported.
const steps: Record<string, number> = { externalsMs: uptimeMs() }
let previous = steps.externalsMs ?? 0

/** Closes a step of the cold start: `name` gets the time since the previous one. */
export const markBootStep = (name: string) => {
  const now = uptimeMs()
  steps[name] = now - previous
  previous = now
}

/** One line per instance saying where its cold start went, to choose what to
 *  load later. `server ready` gives the total; this gives the split. Logged at
 *  the end of the last step, which finishes after that line. */
export const logBootSteps = () => logger.info('boot steps', { ...steps })
