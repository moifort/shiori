import type { CoverUrl } from '~/domain/book/types'
import * as repository from '~/domain/release/infrastructure/repository'
import type { KeptDescription, Release, ReleaseIdentity } from '~/domain/release/types'
import type { Language } from '~/domain/shared/language'

export namespace ReleaseCommand {
  /** What the web says of an edition, its descriptions kept. */
  export const saveWatch = (watch: Omit<Release, 'descriptions' | 'chosenCover'>): Promise<void> =>
    repository.saveWatch(watch)

  /** Its page's description in one language of the app. */
  export const keepDescription = (
    identity: ReleaseIdentity,
    language: Language,
    kept: KeptDescription,
  ): Promise<Release> => repository.saveDescription(identity, language, kept)

  /** The cover a reader picked for a release, for every reader. */
  export const chooseCover = (key: string, url: CoverUrl, at: Date = new Date()) =>
    repository.saveChosenCover(key, url, at)
}
