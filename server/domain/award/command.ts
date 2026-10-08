import * as repository from '~/domain/award/infrastructure/repository'
import type { AwardInterest } from '~/domain/award/types'

export namespace AwardCommand {
  export const saveInterest = (interest: AwardInterest): Promise<void> =>
    repository.saveInterest(interest)
}
