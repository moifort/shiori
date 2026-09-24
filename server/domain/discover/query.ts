import * as repository from '~/domain/discover/infrastructure/repository'
import type { BookPreview, DiscoverFeed, ReleaseWatch } from '~/domain/discover/types'
import type { UserId } from '~/domain/shared/types'

export namespace DiscoverQuery {
  export const feed = (userId: UserId): Promise<DiscoverFeed | undefined> =>
    repository.findFeed(userId)

  /** Every reader who opened the tab once: the ones the daily refresh keeps up
   *  to date, and nobody else. */
  export const allFeeds = (): Promise<DiscoverFeed[]> => repository.findAllFeeds()

  export const watches = (keys: readonly string[]): Promise<ReleaseWatch[]> =>
    repository.findWatches(keys)

  export const preview = (key: string): Promise<BookPreview | undefined> =>
    repository.findPreview(key)
}
