import { PageCount } from '~/domain/book/primitives'
import { isbn13Of } from '~/domain/scan/business-rules'
import type { LibraryEdition } from '~/domain/scan/types'
import { config } from '~/system/config'
import { createLogger } from '~/system/logger'
import { isPresent, optionally } from '~/utils/input'

const logger = createLogger('google-books')

/** Google Books answers in a few hundred milliseconds; past this, the next
 *  source is the better wait. */
const LOOKUP_TIMEOUT_MS = 5000

/** The most a page of results holds. */
const MAX_RESULTS = 40

/** What names a book to search Google Books with. */
export type SearchedBook = {
  title: string
  author: string
  /** The volume number, said only when the volume is titled after its saga. */
  volume?: number
  /** ISO 639-1, the edition's language: the search keeps to it. */
  language: string
}

type Volume = {
  volumeInfo?: {
    title?: string
    subtitle?: string
    publisher?: string
    publishedDate?: string
    pageCount?: number
    description?: string
    industryIdentifiers?: { type: string; identifier: string }[]
    seriesInfo?: { bookDisplayNumber?: string }
  }
}

/** The editions Google Books lists for a book in one language, in the order it
 *  ranks them; empty when it finds none, or without a key.
 *
 *  Google Books carries the publishers' own feeds, so it names editions in
 *  every language with their ISBN, page count and blurb — where the BnF holds
 *  what was printed in France. Free up to the project's daily quota, and asked
 *  with a key of its own: the anonymous quota is shared by every caller on
 *  Earth and is spent most days.
 *
 *  Never throws: a source that cannot be reached is a lookup the caller makes
 *  another way. */
export const googleBooksEditionsOf = async (book: SearchedBook): Promise<LibraryEdition[]> => {
  const { googleBooksKey } = config()
  if (!googleBooksKey) return []
  const title = `${book.title}${book.volume !== undefined ? ` ${book.volume}` : ''}`
  const query = new URLSearchParams({
    q: `intitle:${title} inauthor:${surnameOf(book.author)}`,
    langRestrict: book.language,
    printType: 'books',
    maxResults: String(MAX_RESULTS),
  })
  try {
    // The key travels in a header, never in the URL an error message names.
    const response = await fetch(`https://www.googleapis.com/books/v1/volumes?${query}`, {
      headers: { 'x-goog-api-key': googleBooksKey },
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (!response.ok) {
      logger.warn('Google Books lookup failed', { status: response.status, title: book.title })
      return []
    }
    const { items } = (await response.json()) as { items?: Volume[] }
    return (items ?? []).map(editionOf).filter(isPresent)
  } catch (error) {
    logger.warn('Google Books lookup failed', { error, title: book.title })
    return []
  }
}

const surnameOf = (author: string) => author.trim().split(/\s+/).at(-1) ?? author

/** One volume as an edition, when it has an ISBN. Exported for its tests. */
export const editionOf = ({ volumeInfo: info }: Volume): LibraryEdition | undefined => {
  const identifiers = info?.industryIdentifiers ?? []
  const isbn13 =
    isbn13Of(identifiers.find((id) => id.type === 'ISBN_13')?.identifier) ??
    isbn13Of(identifiers.find((id) => id.type === 'ISBN_10')?.identifier)
  if (!info || !isbn13) return undefined
  const edition: LibraryEdition = {
    isbn13,
    title: [info.title, info.subtitle].filter(Boolean).join(' — ') || undefined,
    publisher: info.publisher,
    year: /\d{4}/.exec(info.publishedDate ?? '')?.[0],
    pageCount: optionally(info.pageCount, PageCount),
    volume: info.seriesInfo?.bookDisplayNumber,
    summary: info.description ? plainTextOf(info.description) : undefined,
  }
  return Object.fromEntries(
    Object.entries(edition).filter(([, value]) => value !== undefined),
  ) as LibraryEdition
}

/** A description as text: publishers' feeds carry paragraphs and emphasis. */
const plainTextOf = (html: string) =>
  html
    .replace(/<br\s*\/?>|<\/p>/gi, ' ')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/\s+/g, ' ')
    .trim()
