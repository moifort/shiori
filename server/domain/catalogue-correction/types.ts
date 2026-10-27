import type { UserId } from '~/domain/shared/types'

/** The shared catalogues a reader may correct by hand. */
export type CorrectedCatalogue = 'series' | 'author' | 'narrator'

/** A value a correction wrote over, or wrote: a text or a year. Null when the
 *  field was empty, or was cleared. */
export type CorrectedValue = string | number | null

/** One field of a shared catalogue corrected by one reader. The catalogues name
 *  no reader, so who changed what is kept here, apart from them: what finds an
 *  abusive edit and the value to put back. Never read by the app. */
export type CatalogueCorrection = {
  userId: UserId
  catalogue: CorrectedCatalogue
  /** The catalogue document's id: a series id, an author or a narrator key. */
  documentId: string
  field: string
  before: CorrectedValue
  after: CorrectedValue
  correctedAt: Date
}
