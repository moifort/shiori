import * as repository from '~/domain/discovery/infrastructure/repository'
import type {
  AuthorWatch,
  DiscoveryLibraryChange,
  DiscoveryPassState,
  DiscoveryProjection,
  DiscoveryProjectionState,
  DiscoveryReader,
  NarratorWatch,
  ReleaseFormat,
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

  /** The author watches under these keys, in one getAll, keyed by theirs. */
  export const authorWatches = async (keys: readonly string[]): Promise<Map<string, AuthorWatch>> =>
    new Map((await repository.findAuthorWatches(keys)).map((watch) => [watch.key, watch]))

  /** The saga watches looked up before `before` or after `after`: the stale
   *  ones and the ones looked up lately, without the rest. */
  export const watchesCheckedOutside = (before: Date, after: Date): Promise<SagaWatch[]> =>
    repository.findWatchesCheckedOutside(before, after)

  export const authorWatchesCheckedOutside = (before: Date, after: Date): Promise<AuthorWatch[]> =>
    repository.findAuthorWatchesCheckedOutside(before, after)

  export const narratorWatchesCheckedOutside = (
    before: Date,
    after: Date,
  ): Promise<NarratorWatch[]> => repository.findNarratorWatchesCheckedOutside(before, after)

  /** What the last hourly pass left for this one, if it left anything. */
  export const passState = (): Promise<DiscoveryPassState | undefined> => repository.findPassState()

  /** The narrator watches under these keys, in one getAll, keyed by theirs. */
  export const narratorWatches = async (
    keys: readonly string[],
  ): Promise<Map<string, NarratorWatch>> =>
    new Map((await repository.findNarratorWatches(keys)).map((watch) => [watch.key, watch]))

  /** The reader's tab in that format as last worked out, if it was. */
  export const projection = (
    userId: UserId,
    format: ReleaseFormat,
  ): Promise<DiscoveryProjection | undefined> => repository.findProjection(userId, format)

  /** Every projection without its rows: what the hourly pass tells the stale by. */
  export const projectionStates = (): Promise<DiscoveryProjectionState[]> =>
    repository.findProjectionStates()

  /** The last change to what the reader's projections are drawn from, if any. */
  export const libraryChange = (userId: UserId): Promise<DiscoveryLibraryChange | undefined> =>
    repository.findLibraryChange(userId)

  /** The last changes of these readers, in one getAll, keyed by reader. */
  export const libraryChanges = async (
    userIds: readonly UserId[],
  ): Promise<Map<UserId, DiscoveryLibraryChange>> =>
    new Map((await repository.findLibraryChanges(userIds)).map((change) => [change.userId, change]))
}
