import { Isbn13 as Isbn13Of } from '~/domain/book/primitives'
import type { BookLanguage, CoverUrl, Isbn13 } from '~/domain/book/types'
import { amazonCoverOf } from '~/domain/scan/amazon-cover'
import { openLibraryCoverOf, openLibraryIsbnsOf } from '~/domain/scan/open-library'
import { createLogger } from '~/system/logger'
import { isPresent, optionally } from '~/utils/input'

const logger = createLogger('published-cover')

/** A refresh already waits on the model; a cover check must not add much to it. */
const PROBE_TIMEOUT_MS = 3000

/** Below this, an image answered with a 200 is a source's blank stand-in — Amazon's
 *  is a 43-byte transparent GIF — rather than a cover. */
const BLANK_IMAGE_BYTES = 1000

/** The publisher's cover for an ISBN, or undefined when no source has one.
 *
 *  Amazon first: it nearly always has the cover of the exact edition, at a size
 *  a Retina book sheet can draw, where Open Library often lacks recent French
 *  editions or files a stale cover under them. Open Library when Amazon has
 *  nothing, and on its own for a 979 ISBN, which Amazon cannot be asked for.
 *  Never throws, like both lookups it chains. */
export const publishedCoverOf = async (isbn13: Isbn13): Promise<CoverUrl | undefined> =>
  (await amazonCoverOf(isbn13)) ?? (await openLibraryCoverOf(isbn13))

/** Both sources' covers for an ISBN, asked at once, for the reader to pick
 *  between: each is undefined when its source has none. Never throws. */
export const isbnCoversOf = async (
  isbn13: Isbn13,
): Promise<{ amazon?: CoverUrl; openLibrary?: CoverUrl }> => {
  const [amazon, openLibrary] = await Promise.all([
    amazonCoverOf(isbn13),
    openLibraryCoverOf(isbn13),
  ])
  return { amazon, openLibrary }
}

/** The ISBN registration groups an edition in each language is published under:
 *  978-2 and 979-10 are French-speaking publishers, 978-0 and 978-1 English-
 *  speaking ones. A language missing here has no group a cover can be trusted
 *  from, and its shelf books keep the placeholder until they are described. */
const ISBN_GROUPS: Partial<Record<BookLanguage, string[]>> = {
  fr: ['9782', '97910'],
  en: ['9780', '9781', '9798'],
  de: ['9783'],
  ja: ['9784'],
  es: ['97884'],
  it: ['97888', '97912'],
  pt: ['97885', '97865', '978972', '978989'],
  nl: ['97890', '97894'],
}

/** How many of a work's ISBNs are tried for a cover: each costs two lookups. */
const ISBNS_TRIED = 3

/** The ISBNs of a work that belong to an edition in this language, in the order
 *  given. A work's list mixes every edition Open Library knows — the English
 *  omnibus, the Japanese original — and a cover from one of those is a wrong
 *  cover, which reads worse than the placeholder. */
export const isbnsInLanguage = (isbns: readonly string[], language: BookLanguage): Isbn13[] => {
  const groups = ISBN_GROUPS[language] ?? []
  return isbns
    .filter((isbn) => groups.some((group) => isbn.startsWith(group)))
    .map((isbn) => optionally(isbn, Isbn13Of))
    .filter(isPresent)
}

/** A cover for a book known only by what its spine printed — a book added from
 *  a shelf photo, before anything looked it up. Open Library names the work's
 *  ISBNs, the edition's language keeps its own, and the first few go through
 *  `publishedCoverOf`. Possibly another printing's cover: the book's first
 *  description finds its exact ISBN and looks again. Never throws. */
export const shelfCoverOf = async (book: {
  title: string
  author: string
  volume?: number
  language: BookLanguage
}): Promise<CoverUrl | undefined> => {
  const isbns = isbnsInLanguage(await openLibraryIsbnsOf(book), book.language)
  for (const isbn of isbns.slice(0, ISBNS_TRIED)) {
    const cover = await publishedCoverOf(isbn)
    if (cover) return cover
  }
  return undefined
}

/** The covers of a book's other editions in its language, for the reader to
 *  pick from: Open Library names the work's ISBNs, the edition's own is left
 *  out, and the first few go through `publishedCoverOf` at once. Free — no
 *  model, no search billed — and never throws. */
export const otherEditionCoversOf = async (book: {
  title: string
  author: string
  volume?: number
  language: BookLanguage
  isbn13?: Isbn13
}): Promise<CoverUrl[]> => {
  const isbns = isbnsInLanguage(await openLibraryIsbnsOf(book), book.language)
    .filter((isbn) => isbn !== book.isbn13)
    .slice(0, ISBNS_TRIED)
  const covers = await Promise.all(isbns.map(publishedCoverOf))
  return covers.filter(isPresent)
}

/** Whether a published cover stored earlier no longer loads: the source dropped
 *  it, and the app draws its placeholder in its place.
 *
 *  Gone only on a clear answer — a 404 or 410, or a blank image where the cover
 *  was. A redirect is a cover found (Open Library's answer), and a source that
 *  could not be reached says nothing either way: the cover is kept, since a
 *  refresh must not drop a cover over a passing outage. Never throws. */
export const isCoverGone = async (url: CoverUrl): Promise<boolean> => {
  try {
    const response = await fetch(url, {
      method: 'HEAD',
      redirect: 'manual',
      signal: AbortSignal.timeout(PROBE_TIMEOUT_MS),
    })
    if (response.status === 404 || response.status === 410) return true
    if (!response.ok) return false
    const type = response.headers.get('content-type') ?? ''
    const length = Number(response.headers.get('content-length') ?? Number.NaN)
    return !type.startsWith('image/') || length < BLANK_IMAGE_BYTES
  } catch (error) {
    logger.warn('cover probe failed', { error, url })
    return false
  }
}
