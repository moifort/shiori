import * as repository from '~/domain/catalogue-correction/infrastructure/repository'
import type {
  CatalogueCorrection,
  CorrectedCatalogue,
  CorrectedValue,
} from '~/domain/catalogue-correction/types'
import type { UserId } from '~/domain/shared/types'

/** A field before and after, as a correction changed it. */
export type FieldChange = { field: string; before: CorrectedValue; after: CorrectedValue }

export namespace CatalogueCorrectionCommand {
  /** Log what one reader changed in one catalogue, a document per field that
   *  actually changed, in one batch. */
  export const record = (
    userId: UserId,
    catalogue: CorrectedCatalogue,
    documentId: string,
    changes: readonly FieldChange[],
    at: Date = new Date(),
  ): Promise<void> =>
    repository.saveAll(
      changes
        .filter(({ before, after }) => before !== after)
        .map(
          (change): CatalogueCorrection => ({
            userId,
            catalogue,
            documentId,
            ...change,
            correctedAt: at,
          }),
        ),
    )

  /** Erase a reader's corrections from the log with their account. What they
   *  wrote into the catalogues stays: it belongs to nobody now. */
  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
