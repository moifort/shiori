import { createLogger } from '~/system/logger'

const logger = createLogger('request')

/**
 * Logs one line per request with its duration, in dev only.
 *
 * The end-to-end gate had the app stuck on a loading state with no way to tell
 * whether the request never left, never came back, or came back with an error:
 * `nitro dev` prints nothing per request, so the server log showed a clean boot
 * either way. `import.meta.dev` is compile-time, so none of this is in the
 * deployed bundle.
 */
export default defineNitroPlugin((nitroApp) => {
  if (!import.meta.dev) return

  const started = new WeakMap<object, number>()

  nitroApp.hooks.hook('request', (event) => {
    started.set(event, Date.now())
  })

  nitroApp.hooks.hook('afterResponse', (event) => {
    const at = started.get(event)
    const elapsed = at ? `${Date.now() - at}ms` : '?'
    logger.info(`${event.method} ${event.path} → ${event.node.res.statusCode} in ${elapsed}`)
  })
})
