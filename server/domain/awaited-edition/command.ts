import * as repository from '~/domain/awaited-edition/infrastructure/repository'
import type { AwaitedEdition, AwaitedEditionId, EditionWatch } from '~/domain/awaited-edition/types'
import type { UserId } from '~/domain/shared/types'

export namespace AwaitedEditionCommand {
  export const save = (awaited: AwaitedEdition): Promise<AwaitedEdition> => repository.save(awaited)

  /** Stop awaiting these editions. Only the reader's own are named, so an id
   *  of somebody else's is simply not found among them. */
  export const remove = (userId: UserId, ids: readonly AwaitedEditionId[]): Promise<void> =>
    repository.remove(userId, ids)

  /** The alert went out, or was passed over: either way, never again. */
  export const markNotified = (awaited: AwaitedEdition, now: Date): Promise<AwaitedEdition> =>
    repository.save({ ...awaited, notifiedAt: now })

  export const saveWatch = (watch: EditionWatch): Promise<void> => repository.saveWatch(watch)

  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
