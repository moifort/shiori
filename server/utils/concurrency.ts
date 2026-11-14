// Run `work` on every item with never more than `limit` of them in flight: a
// new one starts as one ends. For calls to a service that must not see a burst
// — Amazon's firewall refuses some Kindle endpoints to the few addresses every
// call leaves from — where `bulkSave`'s fifty at once suits Firestore only.
// Items are taken in order; the first rejection rejects the whole run.
export const eachWithAtMostInFlight = async <T>(
  items: readonly T[],
  limit: number,
  work: (item: T) => Promise<unknown>,
): Promise<void> => {
  let next = 0
  const lane = async () => {
    while (next < items.length) {
      const item = items[next] as T
      next += 1
      await work(item)
    }
  }
  await Promise.all(Array.from({ length: Math.max(1, Math.min(limit, items.length)) }, lane))
}
