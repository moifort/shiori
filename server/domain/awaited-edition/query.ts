import * as repository from '~/domain/awaited-edition/infrastructure/repository'
import type { AwaitedEdition, EditionPassState, EditionWatch } from '~/domain/awaited-edition/types'
import type { UserId } from '~/domain/shared/types'

export namespace AwaitedEditionQuery {
  export const byUser = (userId: UserId): Promise<AwaitedEdition[]> =>
    repository.findAllByUser(userId)

  export const all = (): Promise<AwaitedEdition[]> => repository.findAll()

  /** The editions awaited since a moment. */
  export const awaitedSince = (since: Date): Promise<AwaitedEdition[]> =>
    repository.findAwaitedSince(since)

  /** Every edition awaited under these watch keys, in document order. */
  export const byWatchKeys = (keys: readonly string[]): Promise<AwaitedEdition[]> =>
    repository.findByWatchKeys(keys)

  /** What the last hourly pass left for this one, if it left anything. */
  export const passState = (): Promise<EditionPassState | undefined> => repository.findPassState()

  /** The watches under these keys, in one getAll, keyed by theirs. */
  export const watches = async (keys: readonly string[]): Promise<Map<string, EditionWatch>> =>
    new Map((await repository.findWatches(keys)).map((watch) => [watch.key, watch]))
}
