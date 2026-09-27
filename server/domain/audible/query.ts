import { audibleProductUrlOf, readersDueForSync } from '~/domain/audible/business-rules'
import * as repository from '~/domain/audible/infrastructure/repository'
import type { AudibleAsin, ConnectedAccount } from '~/domain/audible/types'
import type { UserId } from '~/domain/shared/types'

export namespace AudibleQuery {
  /** The reader's live Audible link, or nothing.
   *
   *  A document holding only a sign-in in flight reads as "not connected": the
   *  settings screen must offer to connect, not claim an account that no
   *  credentials back. */
  export const accountOf = async (userId: UserId): Promise<ConnectedAccount | undefined> =>
    (await repository.findByUser(userId))?.account

  /** Where a recording the reader imported is found on their store, or nothing
   *  once the account is unlinked: the ASIN belongs to the store it was bought
   *  on, and without the account there is no telling which. The connection is
   *  memoized per request, so a list of audiobooks reads it once. */
  export const recordingUrlOf = async (
    userId: UserId,
    asin: AudibleAsin,
  ): Promise<string | undefined> => {
    const account = await accountOf(userId)
    return account && audibleProductUrlOf(account.marketplace, asin)
  }

  /** Who the nightly job should pass over, the reader least recently synced
   *  first. Readers who turned the sync off are not in it. */
  export const readersToSync = async (): Promise<UserId[]> =>
    readersDueForSync(await repository.findAll())
}
