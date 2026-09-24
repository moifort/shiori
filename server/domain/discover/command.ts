import * as repository from '~/domain/discover/infrastructure/repository'
import type { DiscoverFeed, TranslationWatch } from '~/domain/discover/types'
import type { UserId } from '~/domain/shared/types'

/** How many dismissed works and pushed editions a feed remembers. Past that
 *  the oldest go. */
const REMEMBERED = 500

const remembered = (values: readonly string[], added: string): string[] =>
  [...values.filter((value) => value !== added), added].slice(-REMEMBERED)

export namespace DiscoverCommand {
  export const save = (feed: DiscoverFeed): Promise<DiscoverFeed> => repository.saveFeed(feed)

  /** "Pas intéressé": never propose this work again, nor alert about it. */
  export const dismiss = (feed: DiscoverFeed, workKey: string): Promise<DiscoverFeed> =>
    repository.saveFeed({ ...feed, dismissed: remembered(feed.dismissed, workKey) })

  /** These editions were pushed, or were due while the alert was off: either
   *  way, never again. */
  export const markNotified = (
    feed: DiscoverFeed,
    keys: readonly string[],
  ): Promise<DiscoverFeed> =>
    repository.saveFeed({
      ...feed,
      notified: keys.reduce<string[]>((all, key) => remembered(all, key), feed.notified),
    })

  export const saveWatch = (watch: TranslationWatch): Promise<void> => repository.saveWatch(watch)

  export const deleteForUser = (userId: UserId): Promise<void> => repository.removeFeed(userId)
}
