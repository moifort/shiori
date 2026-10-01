import { readersDueForSync } from '~/domain/kindle/business-rules'
import * as repository from '~/domain/kindle/infrastructure/repository'
import type { ConnectedKindleAccount } from '~/domain/kindle/types'
import type { UserId } from '~/domain/shared/types'

export namespace KindleQuery {
  /** The reader's live Kindle link, or nothing. A document holding only a
   *  sign-in in flight reads as "not connected": the screen must offer to
   *  connect, not claim an account that no credentials back. */
  export const accountOf = async (userId: UserId): Promise<ConnectedKindleAccount | undefined> =>
    (await repository.findByUser(userId))?.account

  /** Who the nightly job should pass over, the reader least recently synced
   *  first. Readers who turned the sync off are not in it. */
  export const readersToSync = async (): Promise<UserId[]> =>
    readersDueForSync(await repository.findAll())
}
