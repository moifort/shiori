import * as repository from '~/domain/award/infrastructure/repository'
import type { FoundWinners } from '~/domain/award/types'

export namespace AwardCommand {
  export const saveWinners = (found: FoundWinners): Promise<void> => repository.saveWinners(found)
}
