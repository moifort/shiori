import { withRequestCacheScope } from '~/system/request-cache'

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
