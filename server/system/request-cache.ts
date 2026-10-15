// Per-request memoization: a domain query called several times within the same
// HTTP request reads once. The cache lives on the H3 event context, so it is
// scoped to the current request and discarded when the request ends — no
// cross-request state, no staleness. Requires `experimental.asyncContext`.
//
// Caveat: the cache is held for the whole request, so a flow that reads, writes,
// then reads again would see pre-write state. Every repository that memoizes a
// read therefore evicts or revises it on write: the app sends a whole screen in
// one document, and a mutation document can carry several writes in a row (the
// book sheet corrects, then rates), each of which must see the one before.
//
// Shared in flight: the app opens on about ten requests at once, and each of
// them used to scan the same library — some 230 documents a request, decoded ten
// times over by the one instance serving them all. A read asked with
// `shareInFlight` is shared by the requests asking the same key while it is in
// flight, and forgotten the moment it answers: nothing is kept between requests.
//
// Sharing must not cost a reader their own writes. A request sent once a
// mutation answered has to see it, as a read of its own would, but a read in
// flight may have started before that mutation committed — on another instance,
// where nothing tells. So a request joins only a read started after it arrived,
// or less than `JOINABLE_BEFORE_ARRIVAL_MS` before: shorter than any round trip
// from a phone, so the read started after anything the phone saw committed. On
// this instance a write also forgets the read in flight under its key, and the
// request that wrote never joins one: it reads on its own, as it always did.

const JOINABLE_BEFORE_ARRIVAL_MS = 10

type RequestContext = {
  _queryCache?: Record<string, unknown>
  _writtenKeys?: Set<string>
  /** When this request first used the cache: no earlier than it arrived. */
  _arrivedAt?: number
}

const contextOrUndefined = (): RequestContext | undefined => {
  try {
    return useEvent().context as RequestContext
  } catch {
    // No request context (e.g. migration scripts, tests).
    return undefined
  }
}

/** The reads in flight that concurrent requests share, by key. */
const inFlight = new Map<string, { read: Promise<unknown>; startedAt: number }>()

const sharedInFlight = <T>(key: string, read: () => Promise<T>, arrivedAt: number): Promise<T> => {
  const pending = inFlight.get(key)
  if (pending && pending.startedAt >= arrivedAt - JOINABLE_BEFORE_ARRIVAL_MS)
    return pending.read as Promise<T>
  const started = read().finally(() => {
    if (inFlight.get(key)?.read === started) inFlight.delete(key)
  })
  inFlight.set(key, { read: started, startedAt: performance.now() })
  return started
}

export const memoizedPerRequest = <T>(
  key: string,
  fn: () => T,
  options: { shareInFlight?: boolean } = {},
): T => {
  const context = contextOrUndefined()
  // No request context — run uncached.
  if (!context) return fn()
  context._arrivedAt ??= performance.now()
  if (!context._queryCache) context._queryCache = {}
  const cache = context._queryCache as Record<string, T>
  if (!(key in cache))
    cache[key] =
      options.shareInFlight && !context._writtenKeys?.has(key)
        ? (sharedInFlight(key, fn as () => Promise<unknown>, context._arrivedAt) as T)
        : fn()
  return cache[key]
}

/** A write under the key: the read in flight may hold what stood before it,
 *  so no request joins it any more, and this one never joins one again. */
const markWritten = (key: string) => {
  inFlight.delete(key)
  const context = contextOrUndefined()
  if (!context) return
  if (!context._writtenKeys) context._writtenKeys = new Set()
  context._writtenKeys.add(key)
}

export const isInRequestCache = (key: string): boolean => {
  try {
    const event = useEvent()
    return Boolean(
      event.context._queryCache && key in (event.context._queryCache as Record<string, unknown>),
    )
  } catch {
    return false
  }
}

export const evictFromRequestCache = (key: string) => {
  markWritten(key)
  const context = contextOrUndefined()
  if (context?._queryCache) delete context._queryCache[key]
}

/** Remember what a direct write just stored, so the rest of the request reads
 *  it without asking Firestore again. Only for a write already applied: a
 *  batched one is not visible until its commit, and must evict instead. */
export const rememberInRequestCache = <T>(key: string, value: T) => {
  evictFromRequestCache(key)
  memoizedPerRequest(key, () => value)
}

/** Apply a write to a memoized value rather than dropping it, so the rest of the
 *  request reads what was written without paying the read again. A no-op when
 *  nothing is memoized under the key. */
export const reviseInRequestCache = <T>(key: string, revise: (value: T) => T) => {
  markWritten(key)
  const cache = contextOrUndefined()?._queryCache as Record<string, T> | undefined
  if (cache && key in cache) cache[key] = revise(cache[key])
}

/** Run `fn` with a cache of its own, dropped when it returns. For a request that
 *  walks many accounts in turn — the nightly sync — which would otherwise hold
 *  every library it passed over until the very end. */
export const withRequestCacheScope = async <T>(fn: () => Promise<T>): Promise<T> => {
  let event: ReturnType<typeof useEvent>
  try {
    event = useEvent()
  } catch {
    return fn()
  }
  const outer = event.context._queryCache
  event.context._queryCache = {}
  try {
    return await fn()
  } finally {
    event.context._queryCache = outer
  }
}
