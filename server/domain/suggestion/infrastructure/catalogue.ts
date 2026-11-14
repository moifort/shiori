import { CoverUrl } from '~/domain/book/primitives'
import type { CoverUrl as CoverUrlType } from '~/domain/book/types'
import { createLogger } from '~/system/logger'
import { openLibraryCoverOfId, searchOpenLibrary } from '~/system/open-library'
import { isTimeout } from '~/utils/fetch'

const logger = createLogger('suggestion')

const LOOKUP_TIMEOUT_MS = 5000

type OpenLibraryAnswer = { docs?: { cover_i?: number }[] }

/** A cover for a book the model named, from Open Library, which is free.
 *  Never a verdict on the book: Open Library misses real ones — *Le Cercle*,
 *  *Chrysalis*, *Collapse* on 2026-10-12 — so a suggestion it does not know is
 *  shown without a cover, never left out. Undefined when it has none or cannot
 *  be reached. */
export const coverOf = async (title: string, author: string): Promise<CoverUrlType | undefined> => {
  try {
    const answer = await searchOpenLibrary<OpenLibraryAnswer>(
      'search.json',
      { title, author, fields: 'cover_i', limit: '3' },
      AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    )
    const coverId = answer.docs?.find((doc) => doc.cover_i)?.cover_i
    return coverId ? CoverUrl(openLibraryCoverOfId(coverId)) : undefined
  } catch (error) {
    // Running out of time is the cutoff above doing its job, not a failure to look into.
    if (isTimeout(error)) logger.info('Open Library search timed out', { title })
    else logger.warn('Open Library search failed', { error, title })
    return undefined
  }
}
