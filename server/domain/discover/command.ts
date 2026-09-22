import * as repository from '~/domain/discover/infrastructure/repository'
import type { DiscoverFeed, GenreList, ReleaseWatch } from '~/domain/discover/types'
import type { UserId } from '~/domain/shared/types'

/** How many dismissed suggestions and pushed releases a feed remembers. Past
 *  that the oldest go: a suggestion dismissed years ago can come back. */
const REMEMBERED = 500

const remembered = (values: readonly string[], added: string): string[] =>
  [...values.filter((value) => value !== added), added].slice(-REMEMBERED)

export namespace DiscoverCommand {
  export const save = (feed: DiscoverFeed): Promise<DiscoverFeed> => repository.saveFeed(feed)

  /** Never propose this book again: the reader dismissed it, or took it. */
  export const dismiss = (feed: DiscoverFeed, key: string): Promise<DiscoverFeed> =>
    repository.saveFeed({ ...feed, dismissed: remembered(feed.dismissed, key) })

  /** These releases were pushed, or were due while the alert was off: either
   *  way, never again. */
  export const markNotified = (
    feed: DiscoverFeed,
    keys: readonly string[],
  ): Promise<DiscoverFeed> =>
    repository.saveFeed({
      ...feed,
      notified: keys.reduce<string[]>((all, key) => remembered(all, key), feed.notified),
    })

  export const saveWatch = (watch: ReleaseWatch): Promise<void> => repository.saveWatch(watch)

  export const saveGenreList = (list: GenreList): Promise<void> => repository.saveGenreList(list)

  export const deleteForUser = (userId: UserId): Promise<void> => repository.removeFeed(userId)
}
