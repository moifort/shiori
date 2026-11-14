import * as repository from '~/domain/release/infrastructure/repository'
import type { KeptDescription, Release } from '~/domain/release/types'
import type { Language } from '~/domain/shared/language'

export namespace ReleaseCommand {
  /** What the web says of an edition, its descriptions kept. */
  export const saveWatch = (watch: Omit<Release, 'descriptions'>): Promise<void> =>
    repository.saveWatch(watch)

  /** Its page's description in one language of the app. */
  export const keepDescription = (
    identity: Omit<Release, 'descriptions' | 'checkedAt' | 'found'>,
    language: Language,
    kept: KeptDescription,
  ): Promise<Release> => repository.saveDescription(identity, language, kept)
}
