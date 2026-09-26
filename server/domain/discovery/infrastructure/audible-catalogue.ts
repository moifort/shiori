import type { AudibleAsin } from '~/domain/audible/types'
import { CoverUrl } from '~/domain/book/primitives'
import type { BookLanguage, CoverUrl as CoverUrlType } from '~/domain/book/types'
import { ReleaseDate } from '~/domain/series/primitives'
import type { ReleaseDate as ReleaseDateType } from '~/domain/series/types'
import { createLogger } from '~/system/logger'
import { optionally } from '~/utils/input'

const logger = createLogger('audible-catalogue')

/** Audible's public catalogue API for each language a recording is sold in —
 *  the one its own apps read, which needs no account to look a product up. */
const API_DOMAINS: Partial<Record<BookLanguage, string>> = {
  fr: 'api.audible.fr',
  de: 'api.audible.de',
  es: 'api.audible.es',
  it: 'api.audible.it',
  ja: 'api.audible.co.jp',
}

/** How Audible names each language on a product. */
const AUDIBLE_LANGUAGES: Partial<Record<BookLanguage, string>> = {
  fr: 'french',
  en: 'english',
  de: 'german',
  es: 'spanish',
  it: 'italian',
  ja: 'japanese',
}

const LOOKUP_TIMEOUT_MS = 5000

type ProductAnswer = {
  product?: {
    title?: string
    release_date?: string
    language?: string
    product_images?: Record<string, string>
  }
}

export type AudibleProduct = { releaseDate?: ReleaseDateType; coverUrl?: CoverUrlType }

/** What Audible's own catalogue says of a recording a model named: its release
 *  day and cover, or `unknown` when no such recording exists in that language —
 *  an ASIN Audible does not know answers an empty product, never a 404 — or
 *  `unreachable` when Audible could not be asked. The product pages themselves
 *  answer robots with a 503, which is why the API is asked instead. */
export const audibleProductOf = async (
  asin: AudibleAsin,
  language: BookLanguage,
): Promise<AudibleProduct | 'unknown' | 'unreachable'> => {
  const domain = API_DOMAINS[language] ?? 'api.audible.com'
  const url = `https://${domain}/1.0/catalog/products/${asin}?response_groups=product_desc,product_attrs,media&image_sizes=500`
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS) })
    if (response.status === 404) return 'unknown'
    if (!response.ok) {
      logger.warn('Audible product lookup failed', { asin, status: response.status })
      return 'unreachable'
    }
    const { product } = (await response.json()) as ProductAnswer
    if (!product?.title) return 'unknown'
    const expected = AUDIBLE_LANGUAGES[language]
    if (expected && product.language && product.language !== expected) return 'unknown'
    return {
      releaseDate: optionally(product.release_date, ReleaseDate),
      coverUrl: optionally(product.product_images?.['500'], CoverUrl),
    }
  } catch (error) {
    logger.warn('Audible product lookup failed', { error, asin })
    return 'unreachable'
  }
}
