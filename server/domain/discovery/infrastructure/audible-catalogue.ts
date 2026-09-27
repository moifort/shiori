import { AudibleAsin } from '~/domain/audible/primitives'
import type { AudibleAsin as AudibleAsinType } from '~/domain/audible/types'
import { CoverUrl } from '~/domain/book/primitives'
import type { BookLanguage, CoverUrl as CoverUrlType } from '~/domain/book/types'
import { ReleaseDate, VolumeNumber } from '~/domain/series/primitives'
import type { ReleaseDate as ReleaseDateType } from '~/domain/series/types'
import { BookTitle } from '~/domain/shared/primitives'
import { createLogger } from '~/system/logger'
import { optionally } from '~/utils/input'
import type { FoundVolume } from '../types'

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

type Relationship = {
  relationship_type?: string
  relationship_to_product?: string
  asin?: string
  sequence?: string
}

type Product = {
  asin?: string
  title?: string
  release_date?: string
  language?: string
  product_images?: Record<string, string>
  relationships?: Relationship[]
}

type ProductAnswer = { product?: Product }

export type AudibleProduct = { releaseDate?: ReleaseDateType; coverUrl?: CoverUrlType }

/** What Audible's own catalogue says of a recording a model named: its release
 *  day and cover, or `unknown` when no such recording exists in that language —
 *  an ASIN Audible does not know answers an empty product, never a 404 — or
 *  `unreachable` when Audible could not be asked. The product pages themselves
 *  answer robots with a 503, which is why the API is asked instead. */
export const audibleProductOf = async (
  asin: AudibleAsinType,
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

/** Audible's answer to one catalogue request, or `unreachable`. */
const askAudible = async <Answer>(
  language: BookLanguage,
  path: string,
): Promise<Answer | 'unreachable'> => {
  const domain = API_DOMAINS[language] ?? 'api.audible.com'
  try {
    const response = await fetch(`https://${domain}/1.0/catalog/${path}`, {
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (!response.ok) {
      logger.warn('Audible catalogue request failed', { path, status: response.status })
      return 'unreachable'
    }
    return (await response.json()) as Answer
  } catch (error) {
    logger.warn('Audible catalogue request failed', { error, path })
    return 'unreachable'
  }
}

/** Every numbered recording of the series one recording belongs to, as
 *  Audible's own catalogue in that language lists it: its number in the series,
 *  title, release day and cover — out or on preorder. What a saga heard is
 *  judged by, since a recording is out when Audible sells it, whatever the web
 *  says of the printed book or of another language. `unknown` when the
 *  recording belongs to no series Audible knows in that language. */
export const audibleSeriesOf = async (
  asin: AudibleAsinType,
  language: BookLanguage,
): Promise<FoundVolume[] | 'unknown' | 'unreachable'> => {
  const withRelationships = 'response_groups=relationships'
  const recording = await askAudible<ProductAnswer>(
    language,
    `products/${asin}?${withRelationships}`,
  )
  if (recording === 'unreachable') return recording
  const seriesAsin = recording.product?.relationships?.find(
    (entry) => entry.relationship_type === 'series' && entry.relationship_to_product === 'parent',
  )?.asin
  if (!seriesAsin) return 'unknown'
  const series = await askAudible<ProductAnswer>(
    language,
    `products/${seriesAsin}?${withRelationships}`,
  )
  if (series === 'unreachable') return series
  const numbers = new Map<string, number>()
  for (const entry of series.product?.relationships ?? []) {
    const number = Number(entry.sequence)
    const numbered =
      entry.relationship_type === 'series' &&
      entry.relationship_to_product === 'child' &&
      entry.asin &&
      Number.isInteger(number) &&
      number > 0
    if (numbered && entry.asin && ![...numbers.values()].includes(number))
      numbers.set(entry.asin, number)
  }
  if (numbers.size === 0) return 'unknown'
  const listed = await askAudible<{ products?: Product[] }>(
    language,
    `products?asins=${[...numbers.keys()].join(',')}&response_groups=product_attrs,media&image_sizes=500`,
  )
  if (listed === 'unreachable') return listed
  const expected = AUDIBLE_LANGUAGES[language]
  const volumes = (listed.products ?? []).flatMap((product): FoundVolume[] => {
    const number = product.asin ? numbers.get(product.asin) : undefined
    const title = optionally(product.title, BookTitle)
    const recorded = optionally(product.asin, AudibleAsin)
    if (number === undefined || !title || !recorded) return []
    if (expected && product.language && product.language !== expected) return []
    const date = optionally(product.release_date, ReleaseDate)
    const coverUrl = optionally(product.product_images?.['500'], CoverUrl)
    return [
      {
        number: VolumeNumber(number),
        title,
        asin: recorded,
        ...(date ? { date } : {}),
        ...(coverUrl ? { coverUrl } : {}),
      },
    ]
  })
  return volumes.length > 0 ? volumes.sort((left, right) => left.number - right.number) : 'unknown'
}
