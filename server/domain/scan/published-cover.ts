import type { CoverUrl, Isbn13 } from '~/domain/book/types'
import { amazonCoverOf } from '~/domain/scan/amazon-cover'
import { openLibraryCoverOf } from '~/domain/scan/open-library'

/** The publisher's cover for an ISBN, or undefined when no source has one.
 *
 *  Amazon first: it nearly always has the cover of the exact edition, at a size
 *  a Retina book sheet can draw, where Open Library often lacks recent French
 *  editions or files a stale cover under them. Open Library when Amazon has
 *  nothing, and on its own for a 979 ISBN, which Amazon cannot be asked for.
 *  Never throws, like both lookups it chains. */
export const publishedCoverOf = async (isbn13: Isbn13): Promise<CoverUrl | undefined> =>
  (await amazonCoverOf(isbn13)) ?? (await openLibraryCoverOf(isbn13))
