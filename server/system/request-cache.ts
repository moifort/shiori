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

export const memoizedPerRequest = <T>(key: string, fn: () => T): T => {
  try {
    const event = useEvent()
    if (!event.context._queryCache) event.context._queryCache = {}
    const cache = event.context._queryCache as Record<string, T>
    if (!(key in cache)) cache[key] = fn()
    return cache[key]
  } catch {
    // No request context (e.g. migration scripts, tests) — run uncached.
    return fn()
  }
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
  try {
    const event = useEvent()
    if (event.context._queryCache)
      delete (event.context._queryCache as Record<string, unknown>)[key]
  } catch {}
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
  try {
    const event = useEvent()
    const cache = event.context._queryCache as Record<string, T> | undefined
    if (cache && key in cache) cache[key] = revise(cache[key])
  } catch {}
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
