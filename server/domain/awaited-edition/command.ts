import * as repository from '~/domain/awaited-edition/infrastructure/repository'
import type {
  AwaitedEdition,
  AwaitedEditionId,
  EditionPassState,
  EditionWatch,
} from '~/domain/awaited-edition/types'
import { ReleaseCommand } from '~/domain/release/command'
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

  /** What the web says of an edition, beside the descriptions its release
   *  keeps. */
  export const saveWatch = ({ descriptions: _, ...watch }: EditionWatch): Promise<void> =>
    ReleaseCommand.saveWatch(watch)

  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)

  /** What the hourly pass leaves for the next one. */
  export const savePassState = (state: EditionPassState): Promise<void> =>
    repository.savePassState(state)
}
