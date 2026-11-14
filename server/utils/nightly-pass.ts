import type { createLogger } from '~/system/logger'
import { withRequestCacheScope } from '~/system/request-cache'

/** How long a nightly run may spend before it stops and leaves the rest for
 *  tomorrow.
 *
 *  Two thirds of the function's 180s ceiling, which leaves a whole reader's pass
 *  of margin: the budget is only checked between readers, so the run overshoots
 *  by however long the last one takes. A 504 in the middle of a pass would leave
 *  a library half-written with nothing recording where it stopped. */
export const NIGHTLY_BUDGET_MS = 120_000

/** How many readers a nightly run passes over side by side. A pass mostly waits
 *  on Amazon, so four multiply what a night reaches (about a dozen readers one at
 *  a time, measured 2026-11-08) without four times the load on one account; kept
 *  low because every call leaves from the same few Google addresses, and
 *  Amazon's firewall already refuses some Kindle endpoints. */
const NIGHTLY_CONCURRENCY = 4

/** What a nightly pass over the readers' accounts did. */
export type NightlyPassRun = {
  synced: number
  /** Readers whose pass threw — one bad Amazon call must not cost the others
   *  their night. */
  failed: number
  /** Readers left for the next run because the time budget ran out. */
  deferred: number
}

type NightlyPassOptions<Reader> = {
  /** One reader's pass: `true` when it synced, `false` when there was nothing
   *  to sync. A throw counts as a failure and is handed to `onFailure`. */
  syncOne: (reader: Reader) => Promise<boolean>
  onFailure: (reader: Reader, error: unknown) => Promise<void> | void
  budgetMs: number
  startedAt: number
  /** How many readers are passed over side by side. */
  concurrency: number
}

/** Pass over the readers in the order given, a few at a time, until the time
 *  budget is spent.
 *
 *  A pass mostly waits on Amazon, so readers side by side cost the instance
 *  nothing and multiply what one night reaches. The budget is checked before each
 *  reader starts, never during one: a reader cut off halfway would leave a
 *  library half-written with nothing recording where it stopped. The run
 *  therefore overshoots by at most one reader's pass, as it did one at a time.
 *  Whoever is not started tonight is counted as deferred; the caller's ordering
 *  puts them first tomorrow.
 *
 *  Each reader gets a request cache of their own, dropped when their pass ends,
 *  so the run never holds every library it walked until the last reader. */
export const passOverReaders = async <Reader>(
  readers: readonly Reader[],
  { syncOne, onFailure, budgetMs, startedAt, concurrency }: NightlyPassOptions<Reader>,
): Promise<NightlyPassRun> => {
  let next = 0
  let synced = 0
  let failed = 0
  let deferred = 0

  const lane = async () => {
    while (next < readers.length) {
      if (Date.now() - startedAt > budgetMs) {
        deferred = readers.length - next
        next = readers.length
        return
      }
      const reader = readers[next]
      next += 1
      try {
        if (await withRequestCacheScope(() => syncOne(reader))) synced += 1
      } catch (error) {
        failed += 1
        await onFailure(reader, error)
      }
    }
  }

  const lanes = Math.max(1, Math.min(concurrency, readers.length))
  await Promise.all(Array.from({ length: lanes }, lane))
  return { synced, failed, deferred }
}

/** The nightly job of an Amazon integration: every reader who left its sync on,
 *  in the order given — stalest first.
 *
 *  Bounded by time rather than by a count, because what the run is really
 *  racing is the function's own ceiling — a 500-title library and a 5-title one
 *  cost nothing alike. Whoever is not reached tonight sorts to the front
 *  tomorrow, so the queue drains instead of starving anyone.
 *
 *  A reader's pass synced when `syncLibrary` answers a report, an object; a
 *  refusal — not connected, sync turned off — is a string. `afterSync` then
 *  runs for that reader. One reader's failure is logged, handed to
 *  `afterFailure`, and stepped over: Amazon refusing one account — a revoked
 *  device, a changed password — must not cost every other reader their night,
 *  and there is no one awake to retry for. */
export const syncEveryConnectedReader = async <Reader>(
  readers: readonly Reader[],
  {
    syncLibrary,
    afterSync,
    afterFailure,
    logger,
    budgetMs,
    startedAt,
  }: {
    syncLibrary: (reader: Reader) => Promise<object | string>
    afterSync: (reader: Reader) => Promise<void>
    afterFailure?: (reader: Reader) => Promise<void>
    logger: ReturnType<typeof createLogger>
    budgetMs: number
    startedAt: number
  },
): Promise<NightlyPassRun> => {
  const run = await passOverReaders(readers, {
    syncOne: async (reader) => {
      const synced = typeof (await syncLibrary(reader)) === 'object'
      if (synced) await afterSync(reader)
      return synced
    },
    onFailure: async (reader, error) => {
      logger.warn('nightly sync failed', { error, userId: reader })
      await afterFailure?.(reader)
    },
    budgetMs,
    startedAt,
    concurrency: NIGHTLY_CONCURRENCY,
  })
  if (run.deferred > 0)
    logger.warn('nightly sync budget spent, readers left for tomorrow', {
      synced: run.synced,
      deferred: run.deferred,
    })
  return run
}
