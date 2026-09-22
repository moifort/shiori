import type { LocalizedSubgenre } from '~/domain/book/types'
import * as repository from '~/domain/subgenre/infrastructure/repository'

export namespace SubgenreCommand {
  /** Files translations in the shared dictionary, so the next reader who types
   *  one of these labels, in either language, costs no model call. */
  export const remember = (subgenres: readonly LocalizedSubgenre[]): Promise<void> =>
    repository.save(subgenres)
}
