import type { KindleTitle } from 'kindle-api-ts'
import { AdminCommand } from '~/domain/admin/command'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { mediaFor, shelfOf } from '~/domain/book/business-rules'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import {
  acquiredSince,
  bookFrom,
  importableFrom,
  isCataloguable,
  type KindleLink,
  kindleLinksFor,
  readAsinsOf,
  readingChangesFor,
  readTitleFrom,
} from '~/domain/kindle/business-rules'
import { KindleCommand } from '~/domain/kindle/command'
import { bookFrom as exportedBookFrom, importablesFrom } from '~/domain/kindle/export-rules'
import { openCredentials } from '~/domain/kindle/infrastructure/credentials-vault'
import * as api from '~/domain/kindle/infrastructure/kindle-api'
import { readTitles, TITLES_PER_CALL } from '~/domain/kindle/infrastructure/title-reader'
import { KindleQuery } from '~/domain/kindle/query'
import type {
  ConnectedKindleAccount,
  ExportedKindleBook,
  ImportableKindleBook,
  KindleAsin,
  KindleLibrarySync,
  KindleSyncRun,
  ReadKindleTitle,
  UnreadableExport,
} from '~/domain/kindle/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import type { UserId } from '~/domain/shared/types'
import { config } from '~/system/config'
import { createLogger } from '~/system/logger'
import { withRequestCacheScope } from '~/system/request-cache'
import { bulkSave } from '~/utils/firestore'
import { isPresent } from '~/utils/input'

const logger = createLogger('kindle')

/** How long a nightly run may spend before it leaves the rest for tomorrow: two
 *  thirds of the function's 180s ceiling, checked between readers. */
const SYNC_BUDGET_MS = 120_000

export namespace KindleUseCase {
  /** The reader's Kindle library, as books they could catalogue. Nothing is
   *  saved: the answer is a proposal, the contract a scan has. */
  export const importableBooks = async (
    userId: UserId,
  ): Promise<ImportableKindleBook[] | 'not-connected'> => {
    const titles = await fetchLibrary(userId)
    if (titles === 'not-connected') return titles
    return toImportable(titles, await BookQuery.all(userId), await readingsOf(titles))
  }

  /** Catalogue the titles the reader ticked.
   *
   *  The library is read again rather than trusted from the app: the client sends
   *  identifiers, every stored field comes from Amazon through the mapping the
   *  preview used. A title already on the shelf is skipped however it was
   *  ticked, so a retry creates no duplicate. The dashboard is marked stale
   *  before the first book lands; its next read rebuilds it. */
  export const importBooks = async (
    userId: UserId,
    asins: readonly KindleAsin[],
    now = new Date(),
  ): Promise<Book[] | 'not-connected'> => {
    const titles = await fetchLibrary(userId)
    if (titles === 'not-connected') return titles

    const wanted = new Set<string>(asins)
    // The preview's readings, from the shared store: the book written is the
    // one the reader ticked, not a second answer of the model.
    const owned = await BookQuery.all(userId)
    const reads = await readingsOf(titles, now)
    const chosen = toImportable(titles, owned, reads).filter(
      (importable) => wanted.has(importable.asin) && !importable.alreadyInLibrary,
    )
    // A title the reader already holds on paper was shown "already there": it
    // joins that record here, as the nightly pass would join it.
    const links = kindleLinksFor(owned, titles, reads)
    if (links.length > 0)
      await AnalyticsUseCase.whileStale(userId, () => linkAll(userId, links, now))
    const imported = await catalogue(userId, chosen, now)
    // The read set is the nightly pass's to keep. An import before any pass
    // leaves it absent, so the first pass still reads every title Amazon reports
    // read as news for the books already on the shelf.
    const account = await KindleQuery.accountOf(userId)
    await KindleCommand.recordPass(userId, account?.readAsins && readAsinsOf(titles), now)
    return imported
  }

  /** One pass over a reader's library.
   *
   *  In an order that matters. Ebooks catalogued before the link are linked
   *  first, so they take part in the very pass that links them. Then books Amazon
   *  newly reports read move to read, dated tonight — the sync hears of a
   *  finished book within a day. Then titles acquired since the last pass are
   *  catalogued, and only those: everything older was on offer when the reader
   *  last chose.
   *
   *  `autoSync` governs the nightly pass, not a button: `onDemand` walks past
   *  it. */
  export const syncLibrary = async (
    userId: UserId,
    now = new Date(),
    onDemand = false,
  ): Promise<KindleLibrarySync | 'not-connected' | 'sync-disabled'> => {
    const account = await KindleQuery.accountOf(userId)
    if (!account) return 'not-connected'
    // Checked before the trip to Amazon: a reader who turned the sync off
    // should not cost a cookie exchange.
    if (!onDemand && account.autoSync === false) return 'sync-disabled'

    const titles = await fetchLibrary(userId)
    if (titles === 'not-connected') return titles

    const owned = await BookQuery.all(userId)
    const fresh = acquiredSince(titles, account.lastImportedAt)
    const { links, linked, reads } = await linksOf(owned, titles, fresh, now)
    const moves = readingChangesFor(linked, titles, account.readAsins)
    const acquired = toImportable(fresh, linked, reads).filter(
      (importable) => !importable.alreadyInLibrary,
    )

    const write = async () => {
      await linkAll(userId, links, now)
      await bulkSave(moves, async (bookId) => BookCommand.setStatus(userId, bookId, 'read', now))
      await bulkSave(
        await SeriesUseCase.namedAfterCatalogues(acquired.map(bookFrom)),
        async (book) => BookCommand.add(userId, book, now),
      )
    }
    // A night with nothing new leaves the dashboard as it was.
    if (links.length + moves.length + acquired.length > 0) {
      await AnalyticsUseCase.whileStale(userId, write)
    }

    await KindleCommand.recordPass(userId, readAsinsOf(titles), now)
    return { linked: links.length, moved: moves.length, imported: acquired.length }
  }

  /** The nightly job: every reader who left the sync on, staleest first.
   *
   *  Bounded by time rather than by a count; whoever is not reached tonight sorts
   *  to the front tomorrow. One reader's failure is recorded on their connection,
   *  logged, and stepped over: Amazon refusing one account must not cost every
   *  other reader their night. */
  export const syncEveryReader = async (
    budgetMs = SYNC_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<KindleSyncRun> => {
    const readers = await KindleQuery.readersToSync()
    let synced = 0
    let failed = 0

    for (const [index, userId] of readers.entries()) {
      if (Date.now() - startedAt > budgetMs) {
        const deferred = readers.length - index
        logger.warn('nightly Kindle sync budget spent, readers left for tomorrow', {
          synced: index,
          deferred,
        })
        return { synced, failed, deferred }
      }
      try {
        // A cache of its own per reader: the run is one request, and it must not
        // hold every library it has passed over until the last reader.
        const outcome = await withRequestCacheScope(() => syncLibrary(userId))
        if (typeof outcome === 'object') synced += 1
      } catch (error) {
        failed += 1
        logger.warn('nightly Kindle sync failed', { error, userId })
        await KindleCommand.recordFailure(userId).catch((recordError) =>
          logger.warn('Kindle sync failure could not be recorded', { error: recordError, userId }),
        )
      }
    }
    return { synced, failed, deferred: 0 }
  }

  /** What an Amazon data export holds, ticked against the library it would join.
   *  Saves nothing. Kept for the deprecated export import. */
  export const readExport = async (
    userId: UserId,
    csv: string,
  ): Promise<ExportedKindleBook[] | UnreadableExport> =>
    importablesFrom(csv, await BookQuery.all(userId))

  /** Catalogue the export rows the reader ticked, from a second read of the same
   *  file. Kept for the deprecated export import. */
  export const importExport = async (
    userId: UserId,
    csv: string,
    keys: readonly string[],
  ): Promise<Book[] | UnreadableExport> => {
    const found = await readExport(userId, csv)
    if (found === 'no-title-column') return found

    const wanted = new Set(keys)
    const chosen = found.filter(
      (importable) => wanted.has(importable.key) && !importable.alreadyInLibrary,
    )
    const imported: Book[] = []
    if (chosen.length > 0) {
      const named = await SeriesUseCase.namedAfterCatalogues(chosen.map(exportedBookFrom))
      await AnalyticsUseCase.whileStale(userId, () =>
        bulkSave(named, async (book) => {
          imported.push(await BookCommand.add(userId, book))
        }),
      )
    }
    return imported
  }
}

/** The books the pass links to their Kindle title, the library as it reads once
 *  they are linked, and the readings the pass works from.
 *
 *  Linking matches the titles no book holds yet against the read books still
 *  unlinked; with none of either, only the new titles need reading. */
const linksOf = async (
  owned: readonly Book[],
  titles: readonly KindleTitle[],
  fresh: readonly KindleTitle[],
  now: Date,
) => {
  const taken = new Set<string>(owned.flatMap((book) => (book.kindleAsin ? [book.kindleAsin] : [])))
  const unlinked = owned.some((book) => book.format !== 'audiobook' && !book.kindleAsin)
  const untaken = titles.filter((title) => !taken.has(title.asin))
  const reads = await readingsOf(unlinked ? untaken : fresh, now)
  const links = kindleLinksFor(owned, titles, reads)
  const linked = owned.map((book) => {
    const link = links.find((candidate) => candidate.bookId === book.id)
    return link
      ? {
          ...book,
          kindleAsin: link.kindleAsin,
          media: mediaFor(book.format, [...book.media, 'digital']),
        }
      : book
  })
  return { links, linked, reads }
}

const linkAll = (userId: UserId, links: KindleLink[], now: Date) =>
  bulkSave(links, async (link) =>
    BookCommand.linkToKindle(
      userId,
      link.bookId,
      { asin: link.kindleAsin, coverUrl: link.coverUrl },
      now,
    ),
  )

/** Write the chosen books, each saga named as its catalogue names it. */
const catalogue = async (
  userId: UserId,
  chosen: readonly ImportableKindleBook[],
  now: Date,
): Promise<Book[]> => {
  const imported: Book[] = []
  if (chosen.length === 0) return imported
  const named = await SeriesUseCase.namedAfterCatalogues(chosen.map(bookFrom))
  await AnalyticsUseCase.whileStale(userId, () =>
    bulkSave(named, async (book) => {
      imported.push(await BookCommand.add(userId, book, now))
    }),
  )
  return imported
}

/** One trip to Amazon: fresh cookies minted from the device, then the list. */
const fetchLibrary = async (userId: UserId): Promise<KindleTitle[] | 'not-connected'> => {
  const connected = await connectedCredentials(userId)
  if (connected === 'not-connected') return connected
  return api.library(connected.credentials)
}

/** The reader's account and its credentials, opened.
 *
 *  Credentials sealed with a key that no longer exists cannot be opened again,
 *  and never will be. That is a connection in name only, so it is dropped rather
 *  than reported as an Amazon failure the reader could retry forever: the app
 *  then offers to connect again, which is the one thing that works. */
const connectedCredentials = async (userId: UserId) => {
  const account = await KindleQuery.accountOf(userId)
  if (!account) return 'not-connected' as const
  const credentials = opened(account.credentials)
  if (!credentials) {
    logger.warn('unreadable Kindle credentials, connection dropped', { userId })
    await KindleCommand.disconnect(userId)
    return 'not-connected' as const
  }
  return { account, credentials }
}

const opened = (sealed: ConnectedKindleAccount['credentials']) => {
  try {
    return openCredentials(sealed)
  } catch {
    return undefined
  }
}

const toImportable = (
  titles: readonly KindleTitle[],
  owned: readonly Book[],
  reads: ReadonlyMap<string, ReadKindleTitle>,
): ImportableKindleBook[] => {
  const shelf = shelfOf(owned)
  return titles.map((title) => importableFrom(title, shelf, reads)).filter(isPresent)
}

/** The model's reading of each title, by ASIN: from the shared store when a
 *  reader already paid for it, from the model otherwise, a batch of titles per
 *  call and the calls side by side.
 *
 *  A call that fails costs its titles their reading, not the import: they fall
 *  back on the patterns, and are read again next time since nothing was kept.
 *  The stubbed dev server never calls the model. */
const readingsOf = async (
  titles: readonly KindleTitle[],
  now = new Date(),
): Promise<Map<string, ReadKindleTitle>> => {
  const wanted = titles.filter(isCataloguable)
  const known = new Map(
    (await KindleQuery.readTitles(wanted.map((title) => title.asin))).map((read) => [
      read.asin as string,
      read,
    ]),
  )
  const unread = wanted.filter((title) => known.get(title.asin)?.amazonTitle !== title.title)
  if (unread.length === 0 || (import.meta.dev && config().scanStub)) return known

  const batches = Array.from({ length: Math.ceil(unread.length / TITLES_PER_CALL) }, (_, index) =>
    unread.slice(index * TITLES_PER_CALL, (index + 1) * TITLES_PER_CALL),
  )
  const answers = await Promise.all(
    batches.map(async (batch) => {
      try {
        const { value, usage } = await readTitles(
          batch.map((title) => ({
            asin: title.asin,
            title: title.title,
            author: title.authors[0],
          })),
        )
        if (usage)
          await AdminCommand.recordKindleTitlesUsage(usage).catch((error) =>
            logger.warn('Kindle title reading usage could not be recorded', { error }),
          )
        return value.books ?? []
      } catch (error) {
        logger.warn('Kindle titles could not be read', { error, titles: batch.length })
        return []
      }
    }),
  )

  const byAsin = new Map(unread.map((title) => [title.asin, title]))
  const fresh = answers.flat().flatMap((answer) => {
    const item = answer.asin ? byAsin.get(answer.asin) : undefined
    const read = item && readTitleFrom(item, answer, now)
    return read ? [read] : []
  })
  await KindleCommand.keepReadTitles(fresh)
  for (const read of fresh) known.set(read.asin, read)
  return known
}
