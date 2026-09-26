import * as repository from '~/domain/discovery/infrastructure/repository'
import type { DiscoveryReader, SagaWatch } from '~/domain/discovery/types'
import type { UserId } from '~/domain/shared/types'

export namespace DiscoveryQuery {
  export const reader = (userId: UserId): Promise<DiscoveryReader | undefined> =>
    repository.findReader(userId)

  export const allReaders = (): Promise<DiscoveryReader[]> => repository.findAllReaders()

  /** The watches under these keys, in one getAll, keyed by theirs. */
  export const watches = async (keys: readonly string[]): Promise<Map<string, SagaWatch>> =>
    new Map((await repository.findWatches(keys)).map((watch) => [watch.key, watch]))
}
