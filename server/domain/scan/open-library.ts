import { CoverUrl } from '~/domain/book/primitives'
import type { CoverUrl as CoverUrlType, Isbn13 } from '~/domain/book/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('open-library')

/** The medium size, 180 × ~300 px and around 20 KB. The small one is 58 px tall
 *  and blurs on a Retina list row; the app scales this one down instead. */
const coverUrlOf = (isbn13: Isbn13) => `https://covers.openlibrary.org/b/isbn/${isbn13}-M.jpg`

/** A slow answer costs the reader a longer scan for a cosmetic field. Past this,
 *  the book is added without a cover rather than kept waiting. */
const LOOKUP_TIMEOUT_MS = 3000

/** Open Library's cover for an ISBN, or undefined when it has none.
 *
 *  Checked once, at scan time, so a library of 300 books never probes 300 URLs.
 *  `default=false` is what makes the check possible: without it a missing cover
 *  answers 200 with a blank 1×1 image, which the app would draw as an empty frame
 *  instead of the placeholder. With it, a missing cover is a 404.
 *
 *  The redirect is not followed. A found cover answers 302 to an archive.org
 *  mirror that takes two seconds to serve; the redirect alone is the answer, in
 *  a fraction of that. The URL kept is the stable one, not the mirror's, and it
 *  carries `default=false` too: a cover that later disappears then fails to load,
 *  and the app falls back to its placeholder rather than a blank frame.
 *
 *  Never throws: a failed lookup is a book without a cover, not a failed scan. */
export const openLibraryCoverOf = async (isbn13: Isbn13): Promise<CoverUrlType | undefined> => {
  const url = coverUrlOf(isbn13)
  try {
    const response = await fetch(`${url}?default=false`, {
      method: 'HEAD',
      redirect: 'manual',
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (response.status === 404) return undefined
    if (response.ok || (response.status >= 300 && response.status < 400))
      return CoverUrl(`${url}?default=false`)
    logger.warn('Open Library cover lookup failed', { isbn13, status: response.status })
    return undefined
  } catch (error) {
    logger.warn('Open Library cover lookup failed', { error, isbn13 })
    return undefined
  }
}
