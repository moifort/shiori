import { authorKeyOf, PortraitUrl } from '~/domain/author/primitives'
import type { PortraitUrl as PortraitUrlType } from '~/domain/author/types'
import type { AuthorName } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('open-library-author')

/** A slow answer costs the reader a longer opening for a cosmetic field. */
const LOOKUP_TIMEOUT_MS = 3000

type SearchAnswer = { docs?: { key?: string; name?: string; work_count?: number }[] }

/** The medium size, around 180 px wide: enough for an 84-point circle. */
const photoUrlOf = (olid: string) =>
  `https://covers.openlibrary.org/a/olid/${olid}-M.jpg?default=false`

/** Open Library's photograph of an author, or undefined when it has none.
 *
 *  Asked when Wikipedia has no face for the author: Open Library keeps photos of
 *  writers no Wikipedia page shows. An author search returns namesakes and
 *  duplicates of one writer, so only the entries whose name folds into the
 *  author's own are kept, and the one with the most works — the record the
 *  library maintains — is the one asked for its photo. `default=false` turns a
 *  missing photo into a 404 rather than a blank image.
 *
 *  Never throws: a missing portrait is the initials, not a failed page. */
export const openLibraryPortraitOf = async (
  name: AuthorName,
): Promise<PortraitUrlType | undefined> => {
  try {
    const query = new URLSearchParams({ q: name, fields: 'key,name,work_count', limit: '5' })
    const response = await fetch(`https://openlibrary.org/search/authors.json?${query}`, {
      // Open Library asks every client to say who it is, and throttles those that don't.
      headers: { 'user-agent': 'Shiori/1.0 (https://github.com/moifort/shiori)' },
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (!response.ok) {
      logger.warn('Open Library author search failed', { name, status: response.status })
      return undefined
    }
    const key = authorKeyOf(name)
    const olid = (((await response.json()) as SearchAnswer).docs ?? [])
      .filter((doc) => doc.key && doc.name && authorKeyOf(doc.name) === key)
      .toSorted((a, b) => (b.work_count ?? 0) - (a.work_count ?? 0))[0]?.key
    if (!olid) return undefined

    const url = photoUrlOf(olid)
    const photo = await fetch(url, {
      method: 'HEAD',
      redirect: 'manual',
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (photo.status === 404) return undefined
    if (photo.ok || (photo.status >= 300 && photo.status < 400)) return PortraitUrl(url)
    logger.warn('Open Library author photo lookup failed', { name, status: photo.status })
    return undefined
  } catch (error) {
    logger.warn('Open Library author photo lookup failed', { error, name })
    return undefined
  }
}
