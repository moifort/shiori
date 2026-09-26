import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import {
  audibleLinksFor,
  bookFrom,
  boughtSince,
  heardByAsin,
  importableFrom,
  listenedMinutesFor,
  listeningChangesFor,
  purchaseDatesFor,
  seriesVolumesFor,
  shelfKeysOf,
} from '~/domain/audible/business-rules'
import { AudibleCommand } from '~/domain/audible/command'
import * as api from '~/domain/audible/infrastructure/audible-api'
import { openCredentials } from '~/domain/audible/infrastructure/credentials-vault'
import { AudibleQuery } from '~/domain/audible/query'
import type {
  AudibleAsin,
  AudibleMarketplace,
  ConnectedAccount,
  ImportableBook,
  LibrarySync,
  SyncRun,
} from '~/domain/audible/types'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { withRequestCacheScope } from '~/system/request-cache'
import { bulkSave } from '~/utils/firestore'
import { isPresent } from '~/utils/input'

const logger = createLogger('audible')

export namespace AudibleUseCase {
  /** The store the reader's Audible account was opened on, or nothing for a
   *  reader who never connected one — who is then offered no recording. */
  export const marketplaceOf = async (userId: UserId): Promise<AudibleMarketplace | undefined> =>
    (await AudibleQuery.accountOf(userId))?.marketplace

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
    return toImportable(fetched, owned)
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
   *  lands, so it can never look fresh over books it does not count. Its next
   *  read rebuilds it. */
  export const importBooks = async (
    userId: UserId,
    asins: readonly AudibleAsin[],
  ): Promise<Book[] | 'not-connected'> => {
    const fetched = await fetchLibrary(userId)
    if (fetched === 'not-connected') return fetched

    const wanted = new Set<string>(asins)
    const owned = await BookQuery.all(userId)
    const chosen = toImportable(fetched, owned).filter(
      (importable) => wanted.has(importable.asin) && !importable.alreadyInLibrary,
    )

    const imported: Book[] = []
    if (chosen.length > 0) {
      // Each saga named as its catalogue names it, not as Audible titles it.
      const named = await SeriesUseCase.namedAfterCatalogues(chosen.map(bookFrom))
      await AnalyticsUseCase.whileStale(userId, () =>
        bulkSave(named, async (book) => {
          imported.push(await BookCommand.add(userId, book))
        }),
      )
    }

    await AudibleCommand.recordImport(userId)
    return imported
  }

  /** One night's pass over a reader's library.
   *
   *  Three things, in an order that matters. Books imported before the ASIN was
   *  kept are linked first, so they take part in the very pass that links them.
   *  Then statuses follow the listening, and books imported before the purchase
   *  date was kept are dated back to it. Then titles bought since the reader last
   *  looked are catalogued — and only those: everything older was on offer when
   *  they last chose what to import, and importing it now would overrule them.
   *
   *  Unlike `importBooks`, this writes books nobody ticked. That is what the
   *  reader asked for by leaving the sync on, and `autoSync` is how they take it
   *  back — except when they asked for this pass themselves, which is what
   *  `onDemand` says. */
  export const syncLibrary = async (
    userId: UserId,
    now = new Date(),
    onDemand = false,
  ): Promise<LibrarySync | 'not-connected' | 'sync-disabled'> => {
    const account = await AudibleQuery.accountOf(userId)
    if (!account) return 'not-connected'
    // Checked before the trip to Amazon: a reader who turned the sync off should
    // cost neither an API call nor a rotated token.
    //
    // `autoSync` governs the nightly pass, not a button. A reader who left it off
    // and then asked for a pass themselves means it, so `onDemand` walks past the
    // switch rather than reporting a setting back at them.
    if (!onDemand && account.autoSync === false) return 'sync-disabled'

    const fetched = await fetchLibrary(userId)
    if (fetched === 'not-connected') return fetched
    const { items, positions } = fetched

    const owned = await BookQuery.all(userId)
    const links = audibleLinksFor(owned, items)
    const linked = owned.map((book) => {
      const link = links.find((candidate) => candidate.bookId === book.id)
      return link ? { ...book, audibleAsin: link.audibleAsin } : book
    })
    const moves = listeningChangesFor(linked, items, positions)
    const listened = listenedMinutesFor(linked, positions)
    const redates = purchaseDatesFor(linked, items)
    const renumbers = seriesVolumesFor(linked, items)
    const bought = toImportable(
      { items: boughtSince(items, account.lastImportedAt), positions },
      linked,
    ).filter((importable) => !importable.alreadyInLibrary)

    const changed =
      links.length +
      moves.length +
      listened.length +
      redates.length +
      renumbers.length +
      bought.length
    const write = async () => {
      await bulkSave(links, async (link) =>
        BookCommand.linkToAudible(userId, link.bookId, link.audibleAsin),
      )
      // Audible's own finishing date, not tonight's: a title finished last spring
      // that the sync only hears about now must not land on today and rewrite the
      // reading statistics, for the same reason an import does not.
      await bulkSave(moves, async (move) =>
        BookCommand.setStatus(userId, move.bookId, move.status, move.at ?? now),
      )
      // Where the player got to, which the dashboard and the book read the
      // listening progress off.
      await bulkSave(listened, async ({ bookId, listenedMinutes }) =>
        BookCommand.recordListening(userId, bookId, listenedMinutes, now),
      )
      // Books imported before the purchase date was kept all sit on import night;
      // this is what files them under the month they were in fact bought.
      await bulkSave(redates, async ({ bookId, ...dates }) =>
        BookCommand.backdate(userId, bookId, dates, now),
      )
      // Split novels imported before their parts were numbered sit in their
      // saga without a rank; this is what puts them on the volume they are.
      await bulkSave(renumbers, async ({ bookId, volume }) =>
        BookCommand.numberInSeries(userId, bookId, volume, now),
      )
      await bulkSave(await SeriesUseCase.namedAfterCatalogues(bought.map(bookFrom)), async (book) =>
        BookCommand.add(userId, book, now),
      )
    }
    // A night with nothing new leaves the dashboard as it was.
    if (changed > 0) await AnalyticsUseCase.whileStale(userId, write)

    await AudibleCommand.recordImport(userId, now)
    return {
      linked: links.length,
      moved: moves.length,
      imported: bought.length,
      redated: redates.length,
      renumbered: renumbers.length,
    }
  }

  /** The nightly job: every reader who left the sync on, staleest first.
   *
   *  Bounded by time rather than by a count, because what the run is really
   *  racing is the function's own ceiling — a 500-title library and a 5-title one
   *  cost nothing alike. Whoever is not reached tonight sorts to the front
   *  tomorrow, so the queue drains instead of starving anyone.
   *
   *  One reader's failure is logged and stepped over. Amazon refusing one
   *  account — a revoked device, a changed password — must not cost every other
   *  reader their night, and there is no one awake to retry for. */
  export const syncEveryReader = async (
    budgetMs = SYNC_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<SyncRun> => {
    const readers = await AudibleQuery.readersToSync()
    let synced = 0
    let failed = 0

    for (const [index, userId] of readers.entries()) {
      if (Date.now() - startedAt > budgetMs) {
        const deferred = readers.length - index
        logger.warn('nightly sync budget spent, readers left for tomorrow', {
          synced: index,
          deferred,
        })
        return { synced, failed, deferred }
      }
      try {
        // A cache of its own per reader: the run is one request, and it must not
        // hold every library it has passed over until the very last reader.
        const outcome = await withRequestCacheScope(() => syncLibrary(userId))
        if (typeof outcome === 'object') synced += 1
      } catch (error) {
        failed += 1
        logger.warn('nightly Audible sync failed', { error, userId })
      }
    }
    return { synced, failed, deferred: 0 }
  }
}

/** How long a run may spend before it stops and leaves the rest for tomorrow.
 *
 *  Two thirds of the function's 180s ceiling, which leaves a whole reader's pass
 *  of margin: the budget is only checked between readers, so the run overshoots
 *  by however long the last one takes. A 504 in the middle of a pass would leave
 *  a library half-written with nothing recording where it stopped. */
const SYNC_BUDGET_MS = 120_000

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
    logger.warn('unreadable Audible credentials, connection dropped', { userId })
    await AudibleCommand.disconnect(userId)
    return 'not-connected' as const
  }

  const { items, credentials: rotated } = await api.library(credentials)
  // Where the player last stopped in every title, in one pass: the library's
  // own percentage is stale, and this is what decides which titles are being
  // read. Both trips can rotate the token; the last word is what is kept.
  const { positions, credentials: rotatedAgain } = await api.lastPositions(
    rotated,
    items.map((item) => item.asin),
  )
  await AudibleCommand.rememberRotatedCredentials(userId, rotatedAgain)
  return { items, positions, account }
}

const opened = (sealed: ConnectedAccount['credentials']) => {
  try {
    return openCredentials(sealed)
  } catch {
    return undefined
  }
}

const toImportable = (
  fetched: {
    items: Awaited<ReturnType<typeof api.library>>['items']
    positions: Awaited<ReturnType<typeof api.lastPositions>>['positions']
  },
  owned: readonly Book[],
): ImportableBook[] => {
  const ownedKeys = shelfKeysOf(owned)
  const heard = heardByAsin(fetched.positions)
  return fetched.items
    .map((item) => importableFrom(item, ownedKeys, heard.get(item.asin)))
    .filter(isPresent)
}
