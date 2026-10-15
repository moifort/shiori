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
 *  stack; a line with none is reported as a message. An error naming its own
 *  `fingerprint` is one problem wherever it is caught, and is grouped so. A no-op until the Sentry
 *  plugin initialized the SDK, so a local run reports nothing. */
const sentryReport: Report = (level, tag, message, { error, ...extra }) => {
  reportedSinceFlush = true
  Sentry.withScope((scope) => {
    scope.setLevel(level)
    scope.setTag('logger', tag)
    scope.setExtras({ ...extra, message })
    const fingerprint = (error as { fingerprint?: unknown } | undefined)?.fingerprint
    if (Array.isArray(fingerprint)) scope.setFingerprint(fingerprint)
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

export type Severity = 'INFO' | 'WARNING' | 'ERROR'

const serializedError = (error: unknown) =>
  error instanceof Error
    ? { name: error.name, message: error.message, stack: error.stack }
    : String(error)

/** One log as the single JSON line Cloud Logging parses into a structured
 *  entry: `severity` makes `severity>=WARNING` work, the context keys land
 *  under `jsonPayload` where they can be filtered and summed, and the stack
 *  travels inside the one entry instead of being split into one per line. */
export const structuredLine = (
  severity: Severity,
  tag: string,
  message: string,
  { error, ...context }: LogContext = {},
): string => {
  const entry = {
    ...context,
    ...(error === undefined ? {} : { error: serializedError(error) }),
    severity,
    message: `[${tag}] ${message}`,
    tag,
  }
  try {
    return JSON.stringify(entry)
  } catch {
    // A context that cannot be serialized (a cycle, a bigint) still logs its message.
    return JSON.stringify({ severity, message: entry.message, tag })
  }
}

type Write = (severity: Severity, tag: string, message: string, context?: LogContext) => void

const prettyWrite = (tag: string): Write => {
  const logger = consola.withTag(tag)
  return (severity, _tag, message, context) => {
    const rest = context === undefined ? [] : [context]
    if (severity === 'INFO') logger.info(message, ...rest)
    else if (severity === 'WARNING') logger.warn(message, ...rest)
    else logger.error(message, ...rest)
  }
}

const structuredWrite: Write = (severity, tag, message, context) => {
  process.stdout.write(`${structuredLine(severity, tag, message, context)}\n`)
}

/** A built bundle writes JSON lines for Cloud Logging; a dev server keeps
 *  consola's pretty output. `import.meta.dev` is compiled to `false` in a
 *  build and left undefined under `bun test`, which keeps the pretty output. */
const writeFor = (tag: string): Write =>
  import.meta.dev === false ? structuredWrite : prettyWrite(tag)

export const createLogger = (
  tag: string,
  report: Report = sentryReport,
  write: Write = writeFor(tag),
) => ({
  info: (message: string, context?: LogContext) => write('INFO', tag, message, context),
  warn: (message: string, context?: LogContext) => {
    write('WARNING', tag, message, context)
    report('warning', tag, message, context ?? {})
  },
  error: (message: string, context?: LogContext) => {
    write('ERROR', tag, message, context)
    report('error', tag, message, context ?? {})
  },
})
