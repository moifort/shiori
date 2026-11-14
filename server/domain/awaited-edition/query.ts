import * as repository from '~/domain/awaited-edition/infrastructure/repository'
import type { AwaitedEdition, EditionPassState, EditionWatch } from '~/domain/awaited-edition/types'
import { ReleaseQuery } from '~/domain/release/query'
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

  /** The releases under these keys the web was searched for, in one getAll,
   *  keyed by theirs: a release only described is not watched. */
  export const watches = async (keys: readonly string[]): Promise<Map<string, EditionWatch>> =>
    new Map(
      [...(await ReleaseQuery.byKeys(keys)).values()].flatMap((release) =>
        release.checkedAt ? [[release.key, release as EditionWatch] as const] : [],
      ),
    )
}
