import * as repository from '~/domain/discovery/infrastructure/repository'
import type {
  AuthorWatch,
  DiscoveryReader,
  KeptReleaseDescription,
  SagaWatch,
} from '~/domain/discovery/types'
import type { UserId } from '~/domain/shared/types'

export namespace DiscoveryQuery {
  export const reader = (userId: UserId): Promise<DiscoveryReader | undefined> =>
    repository.findReader(userId)

  export const allReaders = (): Promise<DiscoveryReader[]> => repository.findAllReaders()

  /** The watches under these keys, in one getAll, keyed by theirs. */
  export const watches = async (keys: readonly string[]): Promise<Map<string, SagaWatch>> =>
    new Map((await repository.findWatches(keys)).map((watch) => [watch.key, watch]))

  /** The description kept for a shown book under that key, if any. */
  export const description = (key: string): Promise<KeptReleaseDescription | undefined> =>
    repository.findDescription(key)

  /** The descriptions kept under these keys, in one getAll, keyed by theirs. */
  export const descriptions = async (
    keys: readonly string[],
  ): Promise<Map<string, KeptReleaseDescription>> =>
    new Map((await repository.findDescriptions(keys)).map((kept) => [kept.key, kept]))

  /** The author watches under these keys, in one getAll, keyed by theirs. */
  export const authorWatches = async (keys: readonly string[]): Promise<Map<string, AuthorWatch>> =>
    new Map((await repository.findAuthorWatches(keys)).map((watch) => [watch.key, watch]))
}
