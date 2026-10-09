import * as repository from '~/domain/discovery/infrastructure/repository'
import type {
  AuthorWatch,
  DiscoveryReader,
  KeptReleaseDescription,
  SagaWatch,
} from '~/domain/discovery/types'
import type { UserId } from '~/domain/shared/types'

/** How many pushed alerts a reader remembers. Past that the oldest go. */
const REMEMBERED = 500

export namespace DiscoveryCommand {
  /** Keeps a shown book's description for every reader who opens it next. */
  export const keepDescription = (kept: KeptReleaseDescription): Promise<void> =>
    repository.saveDescription(kept)

  export const saveReader = (reader: DiscoveryReader): Promise<DiscoveryReader> =>
    repository.saveReader(reader)

  /** These volumes were pushed, or were due while the alert was off: either
   *  way, never again. */
  export const markNotified = (
    reader: DiscoveryReader,
    keys: readonly string[],
  ): Promise<DiscoveryReader> =>
    repository.saveReader({
      ...reader,
      notified: [...reader.notified.filter((key) => !keys.includes(key)), ...keys].slice(
        -REMEMBERED,
      ),
    })

  /** These volumes were named in a weekly digest, or were new while the alert
   *  was off: either way, never named again. */
  export const markAnnounced = (
    reader: DiscoveryReader,
    keys: readonly string[],
  ): Promise<DiscoveryReader> => {
    const known = reader.announced ?? []
    return repository.saveReader({
      ...reader,
      announced: [...known.filter((key) => !keys.includes(key)), ...keys].slice(-REMEMBERED),
    })
  }

  export const saveWatch = (watch: SagaWatch): Promise<void> => repository.saveWatch(watch)

  export const saveAuthorWatch = (watch: AuthorWatch): Promise<void> =>
    repository.saveAuthorWatch(watch)

  export const deleteForUser = (userId: UserId): Promise<void> => repository.removeReader(userId)
}
