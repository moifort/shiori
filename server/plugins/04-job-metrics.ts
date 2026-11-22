import type { H3Event } from 'h3'
import { createLogger } from '~/system/logger'
import { type ReadMeter, startReadMeter } from '~/system/read-meter'
import { startWriteMeter, type WriteMeter, writesOf } from '~/system/write-meter'

const logger = createLogger('job')

/**
 * One line per scheduled job run (every `/admin/*` call): which job, how long it
 * took, and the Firestore documents it read and wrote. The writes tell a job
 * that adds data from one that runs for nothing, which the request log alone
 * cannot: every run answers 200 either way. Info level, so never sent to
 * Sentry; in a built bundle the context keys land under `jsonPayload`, where the
 * daily health pass sums them per job.
 */
export default defineNitroPlugin((nitroApp) => {
  const runs = new WeakMap<object, { at: number; read: ReadMeter; write: WriteMeter }>()

  nitroApp.hooks.hook('request', (event) => {
    if (!event.path?.startsWith('/admin/')) return
    runs.set(event, {
      at: performance.now(),
      read: startReadMeter(event.context),
      write: startWriteMeter(event.context),
    })
  })

  const report = (event: H3Event, status = event.node.res.statusCode) => {
    const run = runs.get(event)
    if (!run) return
    runs.delete(event)
    const { at, read, write } = run
    logger.info('job served', {
      job: event.path.split('?')[0],
      status,
      durationMs: Math.round(performance.now() - at),
      ...read,
      reads: read.docReads + read.queryDocs,
      ...write,
      writes: writesOf(write),
    })
  }

  // Before the response leaves: once it is sent, Cloud Run may throttle the
  // instance before a later line is written. A run that threw skips that hook
  // and is reported from the error, with the status it will answer.
  nitroApp.hooks.hook('beforeResponse', (event) => report(event))
  nitroApp.hooks.hook('error', (error, { event }) => {
    if (event) report(event, (error as { statusCode?: number }).statusCode ?? 500)
  })
})
