import type { CoverUrl, Isbn13 } from '~/domain/book/types'
import { amazonCoverOf } from '~/domain/scan/amazon-cover'
import { openLibraryCoverOf } from '~/domain/scan/open-library'
import { createLogger } from '~/system/logger'

const logger = createLogger('published-cover')

/** A refresh already waits on the model; a cover check must not add much to it. */
const PROBE_TIMEOUT_MS = 3000

/** Below this, an image answered with a 200 is a source's blank stand-in — Amazon's
 *  is a 43-byte transparent GIF — rather than a cover. */
const BLANK_IMAGE_BYTES = 1000

/** The publisher's cover for an ISBN, or undefined when no source has one.
 *
 *  Amazon first: it nearly always has the cover of the exact edition, at a size
 *  a Retina book sheet can draw, where Open Library often lacks recent French
 *  editions or files a stale cover under them. Open Library when Amazon has
 *  nothing, and on its own for a 979 ISBN, which Amazon cannot be asked for.
 *  Never throws, like both lookups it chains. */
export const publishedCoverOf = async (isbn13: Isbn13): Promise<CoverUrl | undefined> =>
  (await amazonCoverOf(isbn13)) ?? (await openLibraryCoverOf(isbn13))

/** Whether a published cover stored earlier no longer loads: the source dropped
 *  it, and the app draws its placeholder in its place.
 *
 *  Gone only on a clear answer — a 404 or 410, or a blank image where the cover
 *  was. A redirect is a cover found (Open Library's answer), and a source that
 *  could not be reached says nothing either way: the cover is kept, since a
 *  refresh must not drop a cover over a passing outage. Never throws. */
export const isCoverGone = async (url: CoverUrl): Promise<boolean> => {
  try {
    const response = await fetch(url, {
      method: 'HEAD',
      redirect: 'manual',
      signal: AbortSignal.timeout(PROBE_TIMEOUT_MS),
    })
    if (response.status === 404 || response.status === 410) return true
    if (!response.ok) return false
    const type = response.headers.get('content-type') ?? ''
    const length = Number(response.headers.get('content-length') ?? Number.NaN)
    return !type.startsWith('image/') || length < BLANK_IMAGE_BYTES
  } catch (error) {
    logger.warn('cover probe failed', { error, url })
    return false
  }
}
