import * as repository from '~/domain/award/infrastructure/repository'
import type { AwardInterest } from '~/domain/award/types'

export namespace AwardQuery {
  export const interest = (key: string): Promise<AwardInterest | undefined> =>
    repository.findInterest(key)

  export const interests = (): Promise<AwardInterest[]> => repository.findAllInterests()
}
