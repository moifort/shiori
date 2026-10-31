import { shelfKeysOf } from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import type { BookFormat } from '~/domain/book/types'
import { RELEASE_FORMATS } from '~/domain/discovery/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { FriendshipUseCase } from '~/domain/friendship/use-case'
import { feedEventsOf, feedPageOf, upcomingOf } from '~/domain/news/business-rules'
import type { FeedPage, UpcomingRelease } from '~/domain/news/types'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'

export namespace NewsUseCase {
  /** One page of what the reader's friends did lately, newest first: the
   *  friends' shared shelves read once each, and the reader's own library for
   *  the "already yours" mark. */
  export const feed = async (userId: UserId, limit: number, after?: string): Promise<FeedPage> => {
    const [friends, library] = await Promise.all([
      FriendshipUseCase.friends(userId),
      BookQuery.all(userId),
    ])
    return feedPageOf(feedEventsOf(friends, shelfKeysOf(library)), limit, after)
  }

  /** Everything announced across the sagas the reader follows, the authors they
   *  hold and the editions they await, optionally in one format. Read off the
   *  release watches the scheduled passes keep: no web lookup happens here. */
  export const upcoming = async (
    userId: UserId,
    language: Language,
    format?: BookFormat,
  ): Promise<UpcomingRelease[]> => {
    const discoveries = await Promise.all(
      RELEASE_FORMATS.map(async (releaseFormat) => ({
        format: releaseFormat,
        discovery: await DiscoveryUseCase.discover(userId, language, releaseFormat),
      })),
    )
    const releases = upcomingOf(discoveries)
    return format ? releases.filter((release) => release.format === format) : releases
  }
}
