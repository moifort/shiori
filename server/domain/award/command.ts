import * as repository from '~/domain/award/infrastructure/repository'
import type { FoundWinners } from '~/domain/award/types'
import type { UserId } from '~/domain/shared/types'

export namespace AwardCommand {
  export const saveWinners = (found: FoundWinners): Promise<void> => repository.saveWinners(found)

  /** "Pas intéressé": the novel leaves the reader's lists, in every format. */
  export const dismiss = async (userId: UserId, key: string, now = new Date()): Promise<void> => {
    await repository.saveDismissal({ userId, key, dismissedAt: now })
  }

  /** A dismissal taken back: the novel is listed again. */
  export const reconsider = (userId: UserId, key: string): Promise<void> =>
    repository.removeDismissal(userId, key)

  /** Every novel the reader turned down (account deletion). */
  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
