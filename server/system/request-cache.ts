// Per-request memoization: a domain query called several times within the same
// HTTP request reads once. The cache lives on the H3 event context, so it is
// scoped to the current request and discarded when the request ends — no
// cross-request state, no staleness. Requires `experimental.asyncContext`.
//
// Caveat: the cache is held for the whole request, so a flow that reads, writes,
// then reads again would see pre-write state. Fine today: clients send one
// mutation per request and resolvers return from the command, not a re-query.

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
