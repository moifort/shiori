import type { LocalizedSubgenre, Subgenre } from '~/domain/book/types'
import type { Language } from '~/domain/shared/language'
import { translationKeyOf } from '~/domain/subgenre/business-rules'
import * as repository from '~/domain/subgenre/infrastructure/repository'

export namespace SubgenreQuery {
  /** The translations already known for these labels, typed in `language`,
   *  keyed by `translationKeyOf`. A label nobody has translated yet is absent. */
  export const known = (
    labels: readonly Subgenre[],
    language: Language,
  ): Promise<Map<string, LocalizedSubgenre>> =>
    repository.findByKeys([...new Set(labels.map((label) => translationKeyOf(label, language)))])
}
