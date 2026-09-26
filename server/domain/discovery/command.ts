import * as repository from '~/domain/discovery/infrastructure/repository'
import type { DiscoveryReader, SagaWatch } from '~/domain/discovery/types'
import type { UserId } from '~/domain/shared/types'

/** How many pushed alerts a reader remembers. Past that the oldest go. */
const REMEMBERED = 500

export namespace DiscoveryCommand {
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

  export const saveWatch = (watch: SagaWatch): Promise<void> => repository.saveWatch(watch)

  export const deleteForUser = (userId: UserId): Promise<void> => repository.removeReader(userId)
}
