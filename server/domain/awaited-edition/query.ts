import * as repository from '~/domain/awaited-edition/infrastructure/repository'
import type { AwaitedEdition, EditionWatch } from '~/domain/awaited-edition/types'
import type { UserId } from '~/domain/shared/types'

export namespace AwaitedEditionQuery {
  export const byUser = (userId: UserId): Promise<AwaitedEdition[]> =>
    repository.findAllByUser(userId)

  export const all = (): Promise<AwaitedEdition[]> => repository.findAll()

  /** The watches under these keys, in one getAll, keyed by theirs. */
  export const watches = async (keys: readonly string[]): Promise<Map<string, EditionWatch>> =>
    new Map((await repository.findWatches(keys)).map((watch) => [watch.key, watch]))
}
