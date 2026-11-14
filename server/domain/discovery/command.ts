import * as repository from '~/domain/discovery/infrastructure/repository'
import type {
  AuthorWatch,
  DiscoveryPassState,
  DiscoveryProjection,
  DiscoveryReader,
  NarratorWatch,
  SagaWatch,
} from '~/domain/discovery/types'
import type { UserId } from '~/domain/shared/types'

/** How many pushed alerts a reader remembers. Past that the oldest go. */
const REMEMBERED = 500

export namespace DiscoveryCommand {
  /** What the passes need to know of the reader's library, worked out from it
   *  just now. The alerts and digests already sent are kept as they stand. */
  export const rememberLibrary = (
    library: Pick<
      DiscoveryReader,
      'userId' | 'language' | 'sagas' | 'authors' | 'narrators' | 'syncedAt'
    >,
    known: DiscoveryReader | undefined,
  ): Promise<DiscoveryReader> => repository.saveReaderLibrary(library, known)

  /** These volumes were pushed, or were due while the alert was off: either
   *  way, never again. Added to what is stored, not to the pass's copy. */
  export const markNotified = (
    userId: UserId,
    keys: readonly string[],
  ): Promise<DiscoveryReader | undefined> =>
    repository.reviseReader(userId, (stored) =>
      stored ? { ...stored, notified: remembered(stored.notified, keys) } : undefined,
    )

  /** These volumes were named in a weekly digest, or were new while the alert
   *  was off: either way, never named again. */
  export const markAnnounced = (
    userId: UserId,
    keys: readonly string[],
  ): Promise<DiscoveryReader | undefined> =>
    repository.reviseReader(userId, (stored) =>
      stored ? { ...stored, announced: remembered(stored.announced ?? [], keys) } : undefined,
    )

  export const saveWatch = (watch: SagaWatch): Promise<void> => repository.saveWatch(watch)

  export const saveAuthorWatch = (watch: AuthorWatch): Promise<void> =>
    repository.saveAuthorWatch(watch)

  export const saveNarratorWatch = (watch: NarratorWatch): Promise<void> =>
    repository.saveNarratorWatch(watch)

  export const deleteForUser = (userId: UserId): Promise<void> => repository.removeReader(userId)

  /** What the hourly pass leaves for the next one. */
  export const savePassState = (state: DiscoveryPassState): Promise<void> =>
    repository.savePassState(state)

  /** Keeps the reader's tab as worked out; false when too large to keep. */
  export const saveProjection = (projection: DiscoveryProjection): Promise<boolean> =>
    repository.saveProjection(projection)

  /** Something these readers' tabs are drawn from changed just now: their
   *  projections are worked out again before they are read. */
  export const recordLibraryChange = (
    userIds: readonly UserId[],
    changedAt = new Date(),
  ): Promise<void> => repository.saveLibraryChanges(userIds, changedAt)
}

/** The keys known with these added last, the oldest dropped past the limit. */
const remembered = (known: readonly string[], keys: readonly string[]): string[] =>
  [...known.filter((key) => !keys.includes(key)), ...keys].slice(-REMEMBERED)
