import * as repository from '~/domain/award/infrastructure/repository'
import type { FoundWinners } from '~/domain/award/types'
import type { UserId } from '~/domain/shared/types'

export namespace AwardQuery {
  export const foundWinners = (): Promise<FoundWinners[]> => repository.findAllWinners()

  /** The novels the reader turned down. */
  export const dismissedKeys = async (userId: UserId): Promise<Set<string>> =>
    new Set((await repository.findDismissals(userId)).map((dismissal) => dismissal.key))
}
