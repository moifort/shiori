import * as repository from '~/domain/catalogue-correction/infrastructure/repository'
import type { CatalogueCorrection } from '~/domain/catalogue-correction/types'
import type { UserId } from '~/domain/shared/types'

export namespace CatalogueCorrectionQuery {
  /** Everything one reader corrected, for whoever has to undo it. */
  export const byUser = (userId: UserId): Promise<CatalogueCorrection[]> =>
    repository.findAllByUser(userId)
}
