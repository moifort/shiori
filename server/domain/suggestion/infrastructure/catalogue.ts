import { CoverUrl } from '~/domain/book/primitives'
import type { CoverUrl as CoverUrlType } from '~/domain/book/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('suggestion')

const LOOKUP_TIMEOUT_MS = 5000

/** What the catalogues say of a book the model named: whether either knows
 *  it — undefined when neither could be asked — and a cover when one has it. */
export type CatalogueEntry = { known: boolean | undefined; coverUrl?: CoverUrlType }

type OpenLibraryAnswer = { numFound?: number; docs?: { cover_i?: number }[] }
type GoogleBooksAnswer = {
  totalItems?: number
  items?: { volumeInfo?: { imageLinks?: { thumbnail?: string } } }[]
}

/** Asks Open Library, then Google Books, for a title by an author. Open Library
 *  misses real books — *Le Cercle*, *Chrysalis*, *Scalped* on 2026-10-12 — so a
 *  book it does not know is asked of Google Books before it is taken for an
 *  invention. Both are free. A catalogue that cannot be reached says nothing:
 *  a suggestion is never dropped for an outage. */
export const catalogueEntryOf = async (title: string, author: string): Promise<CatalogueEntry> => {
  const openLibrary = await askOpenLibrary(title, author)
  if (openLibrary?.known) return openLibrary
  const google = await askGoogleBooks(title, author)
  if (google?.known) {
    const coverUrl = openLibrary?.coverUrl ?? google.coverUrl
    return { known: true, ...(coverUrl ? { coverUrl } : {}) }
  }
  if (openLibrary === undefined && google === undefined) return { known: undefined }
  return { known: false }
}

const askOpenLibrary = async (title: string, author: string) => {
  const query = new URLSearchParams({ title, author, fields: 'cover_i', limit: '3' })
  try {
    const response = await fetch(`https://openlibrary.org/search.json?${query}`, {
      // Open Library asks every client to say who it is, and throttles those that don't.
      headers: { 'user-agent': 'Shiori/1.0 (https://github.com/moifort/shiori)' },
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (!response.ok) throw new Error(`Open Library answered ${response.status}`)
    const answer = (await response.json()) as OpenLibraryAnswer
    const coverId = answer.docs?.find((doc) => doc.cover_i)?.cover_i
    return {
      known: (answer.numFound ?? 0) > 0,
      ...(coverId
        ? {
            coverUrl: CoverUrl(
              `https://covers.openlibrary.org/b/id/${coverId}-M.jpg?default=false`,
            ),
          }
        : {}),
    }
  } catch (error) {
    logger.warn('Open Library search failed', { error, title })
    return undefined
  }
}

const askGoogleBooks = async (title: string, author: string) => {
  const query = new URLSearchParams({ q: `intitle:${title} inauthor:${author}`, maxResults: '3' })
  try {
    const response = await fetch(`https://www.googleapis.com/books/v1/volumes?${query}`, {
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (!response.ok) throw new Error(`Google Books answered ${response.status}`)
    const answer = (await response.json()) as GoogleBooksAnswer
    const thumbnail = answer.items
      ?.map((item) => item.volumeInfo?.imageLinks?.thumbnail)
      .find((link) => link !== undefined)
    return {
      known: (answer.totalItems ?? 0) > 0,
      ...(thumbnail ? { coverUrl: CoverUrl(thumbnail.replace(/^http:/, 'https:')) } : {}),
    }
  } catch (error) {
    logger.warn('Google Books search failed', { error, title })
    return undefined
  }
}
