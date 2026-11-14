import { CoverUrl } from '~/domain/book/primitives'
import type { CoverUrl as CoverUrlType, Isbn13 } from '~/domain/book/types'
import { createLogger } from '~/system/logger'
import { isTimeout } from '~/utils/fetch'

const logger = createLogger('epagine-cover')

/** A slow answer costs the reader a longer scan for a cosmetic field. */
const LOOKUP_TIMEOUT_MS = 3000

/** ePagine's 500-pixel cover, filed under the EAN's last three digits. */
const coverUrlOf = (isbn13: Isbn13) =>
  `https://images.epagine.fr/${isbn13.slice(-3)}/${isbn13}_1_75.jpg`

/** The cover ePagine — the image server of the French independent booksellers'
 *  sites — holds for an ISBN, or undefined when it has none.
 *
 *  It has the French editions Amazon and Open Library miss: Bragelonne's,
 *  Milady's, the audiobooks of Hardigan. A missing cover answers 200 as well,
 *  with a small PNG drawing of a book, so only a JPEG is a cover.
 *
 *  Never throws: a failed lookup is a book without a cover, not a failed scan. */
export const epagineCoverOf = async (isbn13: Isbn13): Promise<CoverUrlType | undefined> => {
  const url = coverUrlOf(isbn13)
  try {
    const response = await fetch(url, {
      method: 'HEAD',
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (!response.ok) {
      if (response.status !== 404)
        logger.warn('ePagine cover lookup failed', { isbn13, status: response.status })
      return undefined
    }
    return response.headers.get('content-type')?.startsWith('image/jpeg')
      ? CoverUrl(url)
      : undefined
  } catch (error) {
    // Running out of time is the cutoff above doing its job, not a failure to look into.
    if (isTimeout(error)) logger.info('ePagine cover lookup timed out', { isbn13 })
    else logger.warn('ePagine cover lookup failed', { error, isbn13 })
    return undefined
  }
}
