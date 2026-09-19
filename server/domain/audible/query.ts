import * as repository from '~/domain/audible/infrastructure/repository'
import type { ConnectedAccount } from '~/domain/audible/types'
import type { UserId } from '~/domain/shared/types'

export namespace AudibleQuery {
  /** The reader's live Audible link, or nothing.
   *
   *  A document holding only a sign-in in flight reads as "not connected": the
   *  settings screen must offer to connect, not claim an account that no
   *  credentials back. */
  export const accountOf = async (userId: UserId): Promise<ConnectedAccount | undefined> =>
    (await repository.findByUser(userId))?.account
}
