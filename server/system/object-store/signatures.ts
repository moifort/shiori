import type { ObjectPath, SignedUrl } from '~/system/object-store/types'

/** How long a signed URL opens its object. */
export const DOWNLOAD_WINDOW_MS = 60 * 60 * 1000

// A URL is handed out again only while it has at least this long left: enough
// for the app to fetch the image after the screen that carries it has loaded.
const LEAST_TIME_LEFT_MS = 15 * 60 * 1000

const CAPACITY = 20_000

/** Signatures reused across requests. Without a private key on disk, every
 *  signature is a round trip to the IAM signBlob API, and a saga or an author
 *  page signs one per cover: the slowest of those calls held the whole screen.
 *  A cover signed a minute ago for someone else's request is just as good now,
 *  since a signed URL names one object and grants nothing beyond it.
 *
 *  Pending signatures are shared too, so a page asking for the same cover
 *  twice at once signs it once. A failed one is dropped, never kept. Past the
 *  capacity the oldest path is forgotten: a cache, bounded, per instance. */
export const reusingSignatures = (
  sign: (path: ObjectPath) => Promise<SignedUrl>,
  { now = Date.now, capacity = CAPACITY }: { now?: () => number; capacity?: number } = {},
) => {
  const signed = new Map<ObjectPath, { url: Promise<SignedUrl>; reusableUntil: number }>()
  return (path: ObjectPath): Promise<SignedUrl> => {
    const kept = signed.get(path)
    if (kept && kept.reusableUntil > now()) return kept.url
    signed.delete(path)
    const url = sign(path)
    signed.set(path, { url, reusableUntil: now() + DOWNLOAD_WINDOW_MS - LEAST_TIME_LEFT_MS })
    url.catch(() => {
      if (signed.get(path)?.url === url) signed.delete(path)
    })
    if (signed.size > capacity) {
      const oldest = signed.keys().next().value
      if (oldest !== undefined) signed.delete(oldest)
    }
    return url
  }
}
