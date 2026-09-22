import * as Sentry from '@sentry/node'
import { consola } from 'consola'

/** What a log line carries besides its message: the error that caused it, and
 *  whatever identifies the case — a reader, an ISBN, a saga. Kept apart from
 *  the message so the message stays the same from one case to the next, and
 *  Sentry gathers every occurrence of a problem into one issue. */
export type LogContext = { error?: unknown } & Record<string, unknown>

export type Report = (
  level: 'warning' | 'error',
  tag: string,
  message: string,
  context: LogContext,
) => void

let reportedSinceFlush = false

/** Every warning and error goes to Sentry, not only to the logs: a problem the
 *  code catches and recovers from — a model call that failed, a cover lookup
 *  that answered 500, a dashboard left stale — is still a problem, and one
 *  nobody reads the logs for. An error the line carries is reported with its
 *  stack; a line with none is reported as a message. A no-op until the Sentry
 *  plugin initialized the SDK, so a local run reports nothing. */
const sentryReport: Report = (level, tag, message, { error, ...extra }) => {
  reportedSinceFlush = true
  Sentry.withScope((scope) => {
    scope.setLevel(level)
    scope.setTag('logger', tag)
    scope.setExtras({ ...extra, message })
    if (error instanceof Error) Sentry.captureException(error)
    else {
      if (error !== undefined) scope.setExtra('error', String(error))
      Sentry.captureMessage(`[${tag}] ${message}`)
    }
  })
}

/** Sends what the logger reported before the instance loses its CPU: Cloud
 *  Functions throttles it once the response is out, and a queued event would
 *  then never leave. Waits on nothing when nothing was reported. */
export const flushReports = async (): Promise<void> => {
  if (!reportedSinceFlush) return
  reportedSinceFlush = false
  await Sentry.flush(2000)
}

export const createLogger = (tag: string, report: Report = sentryReport) => {
  const logger = consola.withTag(tag)
  const line = (context?: LogContext) => (context === undefined ? [] : [context])
  return {
    info: (message: string, context?: LogContext) => logger.info(message, ...line(context)),
    warn: (message: string, context?: LogContext) => {
      logger.warn(message, ...line(context))
      report('warning', tag, message, context ?? {})
    },
    error: (message: string, context?: LogContext) => {
      logger.error(message, ...line(context))
      report('error', tag, message, context ?? {})
    },
  }
}
