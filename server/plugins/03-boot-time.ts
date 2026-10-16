import { createLogger } from '~/system/logger'

const logger = createLogger('boot')

/**
 * Logs, once per instance, how long the process took to load the bundle.
 *
 * Cloud Run's `container/startup_latencies` measured about 6 s per cold start
 * on 2026-10-15, but it lumps Google's share (scheduling the instance, starting
 * Node and the Functions Framework) with ours (importing the bundle). Plugins run
 * once every module is loaded, so the process's uptime here is our share; the
 * metric minus this figure is Google's. Scale-to-zero is deliberate, so this is
 * for watching the trend, not for keeping instances warm.
 */
export default defineNitroPlugin(() => {
  if (import.meta.dev) return
  logger.info('server ready', {
    uptimeMs: Math.round(process.uptime() * 1000),
    revision: process.env.K_REVISION,
  })
})
