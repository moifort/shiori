import * as repository from '~/domain/award/infrastructure/repository'
import type { FoundWinners } from '~/domain/award/types'

export namespace AwardQuery {
  export const foundWinners = (): Promise<FoundWinners[]> => repository.findAllWinners()
}
