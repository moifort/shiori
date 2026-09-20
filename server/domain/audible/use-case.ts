import { AnalyticsCommand } from '~/domain/analytics/command'
import { bookFrom, importableFrom, shelfKeysOf } from '~/domain/audible/business-rules'
import { AudibleCommand } from '~/domain/audible/command'
import * as api from '~/domain/audible/infrastructure/audible-api'
import { openCredentials } from '~/domain/audible/infrastructure/credentials-vault'
import { AudibleQuery } from '~/domain/audible/query'
import type { AudibleAsin, ConnectedAccount, ImportableBook } from '~/domain/audible/types'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { atomically, bulkSave } from '~/utils/firestore'
import { isPresent } from '~/utils/input'

const logger = createLogger('audible')

export namespace AudibleUseCase {
  /** The reader's Audible library, as books they could catalogue.
   *
   *  Nothing is saved: the answer is a proposal, the same contract `scanBook`
   *  has. The app shows the list, the reader ticks what they want, and
   *  `importAudibleBooks` writes only that. */
  export const importableBooks = async (
    userId: UserId,
  ): Promise<ImportableBook[] | 'not-connected'> => {
    const fetched = await fetchLibrary(userId)
    if (fetched === 'not-connected') return fetched
    const owned = await BookQuery.all(userId)
    return toImportable(fetched.items, owned)
  }

  /** Catalogue the titles the reader ticked.
   *
   *  The library is fetched again rather than trusted from the app: the client
   *  sends identifiers, and every field that lands in the database comes from
   *  Amazon through the same mapping the preview used. An identifier the reader's
   *  library does not hold simply matches nothing.
   *
   *  Books are written one by one rather than in a batch — a library can run past
   *  the 500-write cap — and the dashboard is marked stale before the first one
   *  lands, so it can never look fresh over books it does not count. */
  export const importBooks = async (
    userId: UserId,
    asins: readonly AudibleAsin[],
  ): Promise<Book[] | 'not-connected'> => {
    const fetched = await fetchLibrary(userId)
    if (fetched === 'not-connected') return fetched

    const wanted = new Set<string>(asins)
    const owned = await BookQuery.all(userId)
    const chosen = toImportable(fetched.items, owned).filter(
      (importable) => wanted.has(importable.asin) && !importable.alreadyInLibrary,
    )

    const imported: Book[] = []
    if (chosen.length > 0) {
      await atomically(async (batch) => AnalyticsCommand.markStale(userId, batch))
      await bulkSave(chosen, async (importable) => {
        imported.push(await BookCommand.add(userId, bookFrom(importable)))
      })
    }

    await AudibleCommand.recordImport(userId)
    // Same contract as a book write: a failed rebuild leaves the view stale for
    // the next read to redo, it does not fail the import that already landed.
    try {
      await AnalyticsCommand.refresh(userId)
    } catch (error) {
      logger.warn(`dashboard rebuild failed after import for ${userId}, left stale: ${error}`)
    }
    return imported
  }
}

/** One trip to Amazon, with the rotated access token written back.
 *
 *  The client refreshes an expired token on its own and hands the new
 *  credentials back; storing them is what keeps the next import from paying for
 *  that refresh again. */
const fetchLibrary = async (userId: UserId) => {
  const account = await AudibleQuery.accountOf(userId)
  if (!account) return 'not-connected' as const

  // Credentials sealed with a key that no longer exists cannot be opened again,
  // and never will be. That is a connection in name only, so it is dropped here
  // rather than reported as an Amazon failure the reader could retry forever:
  // the app then offers to connect again, which is the one thing that works.
  const credentials = opened(account.credentials)
  if (!credentials) {
    logger.warn(`unreadable Audible credentials for ${userId}, connection dropped`)
    await AudibleCommand.disconnect(userId)
    return 'not-connected' as const
  }

  const { items, credentials: rotated } = await api.library(credentials)
  await AudibleCommand.rememberRotatedCredentials(userId, rotated)
  return { items, account }
}

const opened = (sealed: ConnectedAccount['credentials']) => {
  try {
    return openCredentials(sealed)
  } catch {
    return undefined
  }
}

const toImportable = (
  items: Awaited<ReturnType<typeof api.library>>['items'],
  owned: readonly Book[],
): ImportableBook[] => {
  const ownedKeys = shelfKeysOf(owned)
  return items.map((item) => importableFrom(item, ownedKeys)).filter(isPresent)
}
