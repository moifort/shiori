import { releaseDescriptionOf, releaseEditionOf } from '~/domain/discovery/business-rules'
import type { ReleaseSeed } from '~/domain/discovery/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import {
  describedFromOf,
  isDescriptionFresh,
  keptDescriptionOf,
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
}
