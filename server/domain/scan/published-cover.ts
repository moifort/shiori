import type { CoverUrl, Isbn13 } from '~/domain/book/types'
import { amazonCoverOf } from '~/domain/scan/amazon-cover'
import { openLibraryCoverOf } from '~/domain/scan/open-library'

/** The publisher's cover for an ISBN, or undefined when no source has one.
 *
 *  Open Library first: it is documented and meant to be linked to. Amazon only
 *  when Open Library has nothing, since its URL pattern is undocumented.
 *  Never throws, like both lookups it chains. */
export const publishedCoverOf = async (isbn13: Isbn13): Promise<CoverUrl | undefined> =>
  (await openLibraryCoverOf(isbn13)) ?? (await amazonCoverOf(isbn13))
