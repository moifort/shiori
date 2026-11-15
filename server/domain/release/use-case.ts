import {
  isbnCoversOf,
  isImageAt,
  otherEditionCoversOf,
} from '~/domain/book/infrastructure/published-cover'
import type { CoverChoice, CoverUrl } from '~/domain/book/types'
import { CatalogueCorrectionCommand } from '~/domain/catalogue-correction/command'
import { releaseDescriptionOf, releaseEditionOf } from '~/domain/discovery/business-rules'
import type { ReleaseSeed } from '~/domain/discovery/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import {
  coverIsbnOf,
  describedFromOf,
  isDescriptionFresh,
  keptDescriptionOf,
  knownCoversOf,
  releaseCoverChoicesOf,
  releaseViewOf,
} from '~/domain/release/business-rules'
import { ReleaseCommand } from '~/domain/release/command'
import { ReleaseQuery } from '~/domain/release/query'
import type { Release, ReleaseIdentity, ReleaseShown, ReleaseView } from '~/domain/release/types'
import type { ScanResult } from '~/domain/scan/types'
import { type ScanOutcome, ScanUseCase } from '~/domain/scan/use-case'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'

/** Why a release could not be described: the reader's allowance, the model. */
export type DescribeRefusal = Exclude<ScanOutcome, ScanResult>

export namespace ReleaseUseCase {
  /** Describe a release for its page, as a scan describes a book: the
   *  grounded model fills in its summary, genre, pages and publisher, and
   *  Audible its narrators and running time for a recording. Kept in the
   *  release, for every reader and every list that shows it, so the call is
   *  paid once and spends nobody's scan; a reader whose allowance is used up
   *  is refused one nobody described yet. The release as it now stands, or
   *  why it could not be described. */
  export const describe = async (
    userId: UserId,
    identity: ReleaseIdentity,
    seed: ReleaseSeed,
    appLanguage: Language,
    now = new Date(),
  ): Promise<Release | DescribeRefusal> => {
    const release = (await ReleaseQuery.byKeys([identity.key])).get(identity.key)
    const kept = keptDescriptionOf(release, seed, appLanguage)
    if (release && kept && isDescriptionFresh(kept, now, seed.releasedOn)) return release
    const edition = seed.language
    const [described, heard] = await Promise.all([
      ScanUseCase.describeShown(userId, releaseEditionOf(seed), appLanguage, {
        watchedIsbn13: seed.isbn13,
        releasedOn: seed.releasedOn,
        siblings: [],
      }),
      seed.format === 'audiobook' && edition
        ? DiscoveryUseCase.audioEditionOf(seed.title, seed.authors[0], edition)
        : undefined,
    ])
    if (typeof described === 'string' || 'failed' in described) return described
    const description = releaseDescriptionOf(
      seed,
      described,
      typeof heard === 'object' ? heard : undefined,
    )
    return ReleaseCommand.keepDescription(identity, appLanguage, {
      description,
      describedAt: now,
      describedFrom: describedFromOf(seed),
    })
  }

  /** Describe what a list shows — an awaited edition, a winner, a discovery,
   *  a saga's volume — and answer it as the list and its page now draw it. */
  export const describeShown = async (
    userId: UserId,
    identity: ReleaseIdentity,
    shown: ReleaseShown,
    appLanguage: Language,
    now = new Date(),
  ): Promise<ReleaseView | DescribeRefusal> => {
    const release = await describe(userId, identity, shown.seed, appLanguage, now)
    if (typeof release === 'string' || 'failed' in release) return release
    return releaseViewOf(shown, release, appLanguage, now)
  }

  /** The covers a reader may pick for a release, the one drawn now first:
   *  what the release knows, and what Amazon and Open Library have for its
   *  ISBN and for its other editions in its language. Free — no model call,
   *  no scan spent — and a source that fails is a cover not offered.
   *  `not-found` when nothing is kept under the key yet. */
  export const coverChoices = async (
    key: string,
    drawn: CoverUrl | undefined,
  ): Promise<CoverChoice[] | 'not-found'> => {
    const release = (await ReleaseQuery.byKeys([key])).get(key)
    if (!release) return 'not-found'
    const isbn13 = coverIsbnOf(release)
    const [byIsbn, otherEditions] = await Promise.all([
      isbn13 ? isbnCoversOf(isbn13) : {},
      // Without an author a title alone is too loose a search to trust a cover from.
      release.author
        ? otherEditionCoversOf({
            title: release.title,
            author: release.author,
            volume: release.series?.volume,
            language: release.language,
            isbn13,
          })
        : [],
    ])
    return releaseCoverChoicesOf(drawn, knownCoversOf(release), { ...byIsbn, otherEditions })
  }

  /** Draw a release with the cover a reader picked, for every reader: a
   *  shared correction, logged with who made it. An address must serve an
   *  image: a pasted link to a shop's page would leave every reader a broken
   *  cover. */
  export const chooseCover = async (
    userId: UserId,
    key: string,
    url: CoverUrl,
    now = new Date(),
  ): Promise<'chosen' | 'not-found' | 'not-an-image'> => {
    if (!(await isImageAt(url))) return 'not-an-image'
    const chosen = await ReleaseCommand.chooseCover(key, url, now)
    if (chosen === 'not-found') return 'not-found'
    await CatalogueCorrectionCommand.record(
      userId,
      'release',
      key,
      [{ field: 'cover', before: chosen.before ?? null, after: url }],
      now,
    )
    return 'chosen'
  }
}
