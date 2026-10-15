import { CoverUrl } from '~/domain/book/primitives'
import type { CoverUrl as CoverUrlType } from '~/domain/book/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('suggestion')

const LOOKUP_TIMEOUT_MS = 5000

type OpenLibraryAnswer = { docs?: { cover_i?: number }[] }

/** A cover for a book the model named, from Open Library, which is free.
 *  Never a verdict on the book: Open Library misses real ones — *Le Cercle*,
 *  *Chrysalis*, *Collapse* on 2026-10-12 — so a suggestion it does not know is
 *  shown without a cover, never left out. Undefined when it has none or cannot
 *  be reached. */
export const coverOf = async (title: string, author: string): Promise<CoverUrlType | undefined> => {
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
    return coverId
      ? CoverUrl(`https://covers.openlibrary.org/b/id/${coverId}-M.jpg?default=false`)
      : undefined
  } catch (error) {
    logger.warn('Open Library search failed', { error, title })
    return undefined
  }
}
