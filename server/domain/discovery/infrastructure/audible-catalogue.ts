import { plainTextOf } from '~/domain/audible/business-rules'
import { AudibleAsin } from '~/domain/audible/primitives'
import type { AudibleAsin as AudibleAsinType } from '~/domain/audible/types'
import {
  CoverUrl,
  ListeningMinutes,
  MAX_NARRATORS,
  NarratorName,
  Publisher,
  Synopsis,
} from '~/domain/book/primitives'
import type { BookLanguage, CoverUrl as CoverUrlType } from '~/domain/book/types'
import { ReleaseDate, VolumeNumber } from '~/domain/series/primitives'
import type { ReleaseDate as ReleaseDateType } from '~/domain/series/types'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import { createLogger } from '~/system/logger'
import { isPresent, optionally } from '~/utils/input'
import { slugify } from '~/utils/slug'
import type { AudibleRecording, FoundVolume } from '../types'

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

type Contributor = { name?: string }

type Product = {
  asin?: string
  title?: string
  release_date?: string
  language?: string
  product_images?: Record<string, string>
  relationships?: Relationship[]
  authors?: Contributor[]
  narrators?: Contributor[]
  publisher_name?: string
  publisher_summary?: string
  merchandising_summary?: string
  runtime_length_min?: number
}

type ProductAnswer = { product?: Product }

export type AudibleProduct = {
  /** The ASIN the reader's store sells it under, which may not be the one named. */
  asin: AudibleAsinType
  releaseDate?: ReleaseDateType
  coverUrl?: CoverUrlType
}

/** A recording as Audible's own catalogue describes it in that language, for
 *  its page before anybody holds it: who wrote and who reads it, its running
 *  time, its publisher and blurb, its cover. `unknown` when Audible does not
 *  sell it in that language, `unreachable` when it could not be asked. */
export const audibleRecordingOf = async (
  asin: AudibleAsinType,
  language: BookLanguage,
): Promise<AudibleRecording | 'unknown' | 'unreachable'> => {
  const answer = await askAudible<ProductAnswer>(
    language,
    `products/${asin}?response_groups=product_desc,product_attrs,contributors,media&image_sizes=500`,
  )
  if (answer === 'unreachable') return answer
  return (answer.product && recordingOf(answer.product, language)) ?? 'unknown'
}

/** The recording Audible sells of a book in its language, found by its title
 *  and first author: whether a reader may take as an audiobook a story a
 *  friend holds on paper. Kept only on the same title and an author of the
 *  same name, folded as the shelf keys fold them, so a study of the book or a
 *  namesake is never taken for it. `unknown` when Audible sells none in that
 *  language, `unreachable` when it could not be asked. */
export const audibleEditionOf = async (
  title: string,
  author: string | undefined,
  language: BookLanguage,
): Promise<AudibleRecording | 'unknown' | 'unreachable'> => {
  const keywords = encodeURIComponent([title, author].filter(Boolean).join(' '))
  const answer = await askAudible<{ products?: Product[] }>(
    language,
    `products?keywords=${keywords}&num_results=20&${PRODUCT_GROUPS}`,
  )
  if (answer === 'unreachable') return answer
  const wanted = { title: slugify(title), author: author ? slugify(author) : undefined }
  const found = (answer.products ?? [])
    .map((product) => recordingOf(product, language))
    .find(
      (recording) =>
        recording &&
        slugify(recording.title) === wanted.title &&
        (!wanted.author || recording.authors.some((name) => slugify(name) === wanted.author)),
    )
  return found ?? 'unknown'
}

/** A product described as a recording, when it has a title and is recorded in
 *  that language. */
const recordingOf = (product: Product, language: BookLanguage): AudibleRecording | undefined => {
  const title = optionally(product.title, BookTitle)
  if (!title) return undefined
  const expected = AUDIBLE_LANGUAGES[language]
  if (expected && product.language && product.language !== expected) return undefined
  const names = <Name>(contributors: Contributor[] | undefined, make: (value: unknown) => Name) =>
    (contributors ?? []).map((contributor) => optionally(contributor.name, make)).filter(isPresent)
  return {
    title,
    authors: names(product.authors, AuthorName),
    narrators: names(product.narrators, NarratorName).slice(0, MAX_NARRATORS),
    publisher: optionally(product.publisher_name, Publisher),
    synopsis: optionally(
      plainTextOf(product.publisher_summary ?? product.merchandising_summary),
      Synopsis,
    ),
    durationMinutes: optionally(product.runtime_length_min, ListeningMinutes),
    coverUrl: optionally(product.product_images?.['500'], CoverUrl),
  }
}

/** What Audible's own catalogue says of a recording a model named: the ASIN
 *  the reader's store sells it under, its release day and cover, or `unknown`
 *  when no such recording exists in that language — an ASIN Audible does not
 *  know answers an empty product, never a 404 — or `unreachable` when Audible
 *  could not be asked. The product pages themselves answer robots with a 503,
 *  which is why the API is asked instead.
 *
 *  A model searching the web often names the audible.com ASIN of a French or
 *  German recording, which the store of that language sells under another one
 *  (Neuromancien: B09VY3W1FF on audible.com, B09VY5GXM7 on audible.fr). So an
 *  ASIN the reader's store does not know is looked up on audible.com, and the
 *  same recording — same title, language and release day — sought in the
 *  reader's store. */
export const audibleProductOf = async (
  asin: AudibleAsinType,
  language: BookLanguage,
): Promise<AudibleProduct | 'unknown' | 'unreachable'> => {
  const domain = API_DOMAINS[language] ?? US_API_DOMAIN
  const product = await productOf(domain, asin, language)
  if (product !== 'unknown' || domain === US_API_DOMAIN) return product
  const elsewhere = await productOf(US_API_DOMAIN, asin, language)
  if (elsewhere === 'unknown' || elsewhere === 'unreachable') return elsewhere
  return sameRecordingIn(domain, elsewhere, language)
}

const US_API_DOMAIN = 'api.audible.com'

const PRODUCT_GROUPS =
  'response_groups=product_desc,product_attrs,contributors,media&image_sizes=500'

type Described = AudibleProduct & { title: string; author?: string }

/** One product as one store describes it, `unknown` when that store does not
 *  sell it in that language. */
const productOf = async (
  domain: string,
  asin: AudibleAsinType,
  language: BookLanguage,
): Promise<Described | 'unknown' | 'unreachable'> => {
  const url = `https://${domain}/1.0/catalog/products/${asin}?${PRODUCT_GROUPS}`
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS) })
    if (response.status === 404) return 'unknown'
    if (!response.ok) {
      logger.warn('Audible product lookup failed', { asin, domain, status: response.status })
      return 'unreachable'
    }
    const { product } = (await response.json()) as ProductAnswer
    return (product && describedOf(product, language)) ?? 'unknown'
  } catch (error) {
    logger.warn('Audible product lookup failed', { error, asin, domain })
    return 'unreachable'
  }
}

/** The recording a store sells as the one described elsewhere: found by its
 *  title and author, and kept only on the same title, language and release
 *  day, so a different edition or reading is never taken for it. */
const sameRecordingIn = async (
  domain: string,
  recording: Described,
  language: BookLanguage,
): Promise<AudibleProduct | 'unknown' | 'unreachable'> => {
  if (!recording.releaseDate) return 'unknown'
  const keywords = encodeURIComponent([recording.title, recording.author].filter(Boolean).join(' '))
  const url = `https://${domain}/1.0/catalog/products?keywords=${keywords}&num_results=20&${PRODUCT_GROUPS}`
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS) })
    if (!response.ok) {
      logger.warn('Audible product search failed', { domain, status: response.status })
      return 'unreachable'
    }
    const { products } = (await response.json()) as { products?: Product[] }
    const same = (products ?? [])
      .map((product) => describedOf(product, language))
      .find(
        (found) =>
          found &&
          found.releaseDate === recording.releaseDate &&
          comparable(found.title) === comparable(recording.title),
      )
    if (!same) return 'unknown'
    const { title: _title, author: _author, ...product } = same
    return product
  } catch (error) {
    logger.warn('Audible product search failed', { error, domain })
    return 'unreachable'
  }
}

/** A product in that language, with the ASIN, title and first author it
 *  carries; nothing when it has no title or is recorded in another language. */
const describedOf = (product: Product, language: BookLanguage): Described | undefined => {
  const asin = optionally(product.asin, AudibleAsin)
  if (!asin || !product.title) return undefined
  const expected = AUDIBLE_LANGUAGES[language]
  if (expected && product.language && product.language !== expected) return undefined
  const releaseDate = optionally(product.release_date, ReleaseDate)
  const coverUrl = optionally(product.product_images?.['500'], CoverUrl)
  return {
    asin,
    title: product.title,
    author: product.authors?.[0]?.name,
    ...(releaseDate ? { releaseDate } : {}),
    ...(coverUrl ? { coverUrl } : {}),
  }
}

const comparable = (title: string) => title.normalize('NFC').trim().toLowerCase()

/** Audible's answer to one catalogue request, or `unreachable`. */
const askAudible = async <Answer>(
  language: BookLanguage,
  path: string,
): Promise<Answer | 'unreachable'> => {
  const domain = API_DOMAINS[language] ?? US_API_DOMAIN
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
