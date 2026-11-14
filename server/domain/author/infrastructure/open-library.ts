import { authorKeyOf, PortraitUrl } from '~/domain/author/primitives'
import type { PortraitUrl as PortraitUrlType } from '~/domain/author/types'
import type { AuthorName } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { probeOpenLibraryImage, searchOpenLibrary } from '~/system/open-library'
import { isTimeout } from '~/utils/fetch'

const logger = createLogger('open-library-author')

/** A slow answer costs the reader a longer opening for a cosmetic field. The
 *  search and the photo probe share this long: Open Library often takes more
 *  than two seconds to search, and three apiece timed out good answers. */
const LOOKUP_TIMEOUT_MS = 5000

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
  const signal = AbortSignal.timeout(LOOKUP_TIMEOUT_MS)
  try {
    const answer = await searchOpenLibrary<SearchAnswer>(
      'search/authors.json',
      { q: name, fields: 'key,name,work_count', limit: '5' },
      signal,
    )
    const key = authorKeyOf(name)
    const olid = (answer.docs ?? [])
      .filter((doc) => doc.key && doc.name && authorKeyOf(doc.name) === key)
      .toSorted((a, b) => (b.work_count ?? 0) - (a.work_count ?? 0))[0]?.key
    if (!olid) return undefined

    const url = photoUrlOf(olid)
    const photo = await probeOpenLibraryImage(url, signal)
    if (photo === 'missing') return undefined
    if (photo === 'found') return PortraitUrl(url)
    logger.warn('Open Library author photo lookup failed', { name, status: photo.status })
    return undefined
  } catch (error) {
    // Running out of time is the cutoff above doing its job, not a failure to look into.
    if (isTimeout(error)) logger.info('Open Library author photo lookup timed out', { name })
    else logger.warn('Open Library author photo lookup failed', { error, name })
    return undefined
  }
}
