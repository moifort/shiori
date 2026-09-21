import { CoverUrl } from '~/domain/book/primitives'
import type { CoverUrl as CoverUrlType, Isbn13 } from '~/domain/book/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('amazon-cover')

/** A slow answer costs the reader a longer scan for a cosmetic field. */
const LOOKUP_TIMEOUT_MS = 3000

/** The ISBN-10 a 978 ISBN-13 was minted from, which is also the ASIN Amazon files
 *  a printed book under. A 979 ISBN never had an ISBN-10, so it has no such ASIN. */
export const isbn10Of = (isbn13: Isbn13): string | undefined => {
  if (!isbn13.startsWith('978')) return undefined
  const body = isbn13.slice(3, 12)
  const sum = [...body].reduce((total, digit, index) => total + Number(digit) * (10 - index), 0)
  const check = (11 - (sum % 11)) % 11
  return `${body}${check === 10 ? 'X' : check}`
}

/** 500 px tall and around 20 KB, the weight of Open Library's medium cover. The
 *  usual `_SL500_` size suffix is ignored on this path, which then serves a
 *  160 px thumbnail that blurs on a Retina book sheet. */
const coverUrlOf = (asin: string) =>
  `https://m.media-amazon.com/images/P/${asin}.01._SCLZZZZZZZ_.jpg`

/** Amazon's cover for an ISBN, or undefined when it has none.
 *
 *  The URL pattern is undocumented and carries no promise of lasting: it is the
 *  fallback behind Open Library, never the first source. A cover that later
 *  disappears fails to load, and the app falls back to its placeholder.
 *
 *  A missing cover still answers 200, with a 43-byte transparent GIF. The
 *  content type tells the two apart without downloading the image.
 *
 *  Never throws: a failed lookup is a book without a cover, not a failed scan. */
export const amazonCoverOf = async (isbn13: Isbn13): Promise<CoverUrlType | undefined> => {
  const asin = isbn10Of(isbn13)
  if (!asin) return undefined
  const url = coverUrlOf(asin)
  try {
    const response = await fetch(url, {
      method: 'HEAD',
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (!response.ok) {
      logger.warn(`cover lookup for ${isbn13} answered ${response.status}`)
      return undefined
    }
    return response.headers.get('content-type')?.startsWith('image/jpeg')
      ? CoverUrl(url)
      : undefined
  } catch (error) {
    logger.warn(`cover lookup for ${isbn13} failed: ${error}`)
    return undefined
  }
}
