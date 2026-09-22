import * as Sentry from '@sentry/node'
import { instrumentDomains } from '#domain-instrumentation'
import { config } from '~/system/config/index'
import { flushReports } from '~/system/logger'

export default defineNitroPlugin((nitroApp) => {
  // Mirrors the iOS `#if DEBUG` gate in ShioriApp.startSentry: only the deployed
  // build reports, so a local run never pollutes the production project.
  // import.meta.dev is compile-time, so the guard costs nothing in the prod bundle
  // and everything below it is tree-shaken out of dev builds.
  if (import.meta.dev) return

  const { sentryDsn, sentryRelease } = config()
  if (!sentryDsn) return

  Sentry.init({
    dsn: sentryDsn,
    environment: 'production',
    release: sentryRelease,
    // Only performance traces are sampled — errors are always sent in full, and
    // each one carries its trace id, so an app error and the resolver that threw
    // still line up in the same trace at a tenth of the transaction volume.
    tracesSampleRate: 0.1,
  })

  instrumentDomains()

  const originalHandler = nitroApp.h3App.handler
  nitroApp.h3App.handler = ((event) =>
    // The app sends its own trace headers, so the request continues the trace the
    // tap on screen started instead of opening a fresh one. That is what puts the
    // iOS error and the backend error it caused side by side in Sentry.
    Sentry.continueTrace(
      {
        sentryTrace: getHeader(event, 'sentry-trace'),
        baggage: getHeader(event, 'baggage'),
      },
      () =>
        Sentry.startSpan(
          { name: `${event.method} ${event.path}`, op: 'http.server' },
          async (span) => {
            try {
              const result = await originalHandler(event)
              const route = event.context.matchedRoute?.path
              if (route) span.updateName(`${event.method} ${route}`)
              return result
            } finally {
              // What the loggers reported while serving — a model call that
              // failed and was recovered from — leaves before the response
              // does, since Cloud Functions throttles the CPU right after.
              await flushReports()
            }
          },
        ),
    )) as typeof originalHandler

  nitroApp.hooks.hook('error', async (error, { event }) => {
    const statusCode = (error as { statusCode?: number }).statusCode
    if (statusCode && statusCode >= 400 && statusCode < 500) return

    // The uid rides on the event rather than a global scope: the function serves
    // up to 80 requests at once, so a shared scope would credit an error to
    // whoever happened to be in flight. It turns "an error" into "how many
    // accounts are affected", and points straight at the documents to inspect.
    const userId = event?.context.userId
    Sentry.captureException(error, {
      user: userId ? { id: userId } : undefined,
      extra: {
        path: event?.path,
        method: event?.method,
      },
    })
    // Cloud Functions gen2 throttles the CPU once the response is sent —
    // flush now or the event may never leave the instance.
    await Sentry.flush(2000)
  })
})
