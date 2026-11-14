import type { KindleCredentials, KindleTitle } from 'kindle-api-ts'
import { AdminCommand } from '~/domain/admin/command'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import {
  kindleMoveOf,
  markedRemovedByReader,
  mediaFor,
  shelfOf,
} from '~/domain/book/business-rules'
import { BookCommand } from '~/domain/book/command'
import { KindlePosition } from '~/domain/book/primitives'
import { BookQuery } from '~/domain/book/query'
import type { Book, BookLanguage, KindlePosition as KindlePositionValue } from '~/domain/book/types'
import { DiscoveryCommand } from '~/domain/discovery/command'
import {
  bookFrom,
  drawnBooksOf,
  importableFrom,
  isCataloguable,
  type KindleLink,
  kindleLinksFor,
  positionsToWatch,
  readAsinsOf,
  readingChangesFor,
  readTitleFrom,
  storeLanguageOf,
  titlesToCatalogue,
  titlesWorthMatching,
} from '~/domain/kindle/business-rules'
import { KindleCommand } from '~/domain/kindle/command'
import { bookFrom as exportedBookFrom, importablesFrom } from '~/domain/kindle/export-rules'
import { openReadableCredentials } from '~/domain/kindle/infrastructure/credentials-vault'
import * as api from '~/domain/kindle/infrastructure/kindle-api'
import { readTitles, TITLES_PER_CALL } from '~/domain/kindle/infrastructure/title-reader'
import { KindleQuery } from '~/domain/kindle/query'
import type {
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
import { openedConnection } from '~/utils/amazon-connection'
import { eachWithAtMostInFlight } from '~/utils/concurrency'
import { bulkSave } from '~/utils/firestore'
import { isPresent } from '~/utils/input'
import { NIGHTLY_BUDGET_MS, syncEveryConnectedReader } from '~/utils/nightly-pass'

const logger = createLogger('kindle')

export namespace KindleUseCase {
  /** The reader's Kindle library, as books they could catalogue. Nothing is
   *  saved: the answer is a proposal, the contract a scan has. */
  export const importableBooks = async (
    userId: UserId,
  ): Promise<ImportableKindleBook[] | 'not-connected'> => {
    const library = await fetchLibrary(userId)
    if (library === 'not-connected') return library
    const { titles, store } = library
    return toImportable(
      titles,
      await BookQuery.all(userId),
      await readingsOf(titles),
      store,
      await BookQuery.removedAsins(userId, 'kindle'),
    )
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
    const library = await fetchLibrary(userId)
    if (library === 'not-connected') return library
    const { titles, store } = library

    const wanted = new Set<string>(asins)
    // The preview's readings, from the shared store: the book written is the
    // one the reader ticked, not a second answer of the model.
    const owned = await BookQuery.all(userId)
    const reads = await readingsOf(titles, now)
    const chosen = toImportable(
      titles,
      owned,
      reads,
      store,
      await BookQuery.removedAsins(userId, 'kindle'),
    ).filter((importable) => wanted.has(importable.asin) && !importable.alreadyInLibrary)
    // A title the reader already holds on paper was shown "already there": it
    // joins that record here, as the nightly pass would join it.
    const links = kindleLinksFor(owned, titles, reads, store)
    if (links.length > 0)
      await AnalyticsUseCase.whileStale(userId, () => linkAll(userId, links, now))
    const imported = await catalogue(userId, chosen, now)
    // Ticked by hand: the reader takes their deletion back.
    await BookCommand.forgetSyncRemovals(
      userId,
      'kindle',
      chosen.filter((importable) => importable.removedByReader).map(({ asin }) => asin),
    )
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
   *  last chose. Last, the books left to finish take their Kindle position: one
   *  Amazon call each, no paid API, and it moves the page the reader sees.
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

    const library = await fetchLibrary(userId)
    if (library === 'not-connected') return library
    const { titles, store, credentials } = library

    const [owned, removals] = await Promise.all([
      BookQuery.all(userId),
      BookQuery.syncRemovals(userId, 'kindle'),
    ])
    // A title whose book the reader deleted stays out, unless Amazon newly
    // reports it read: then it comes back, and the deletion is forgotten.
    const fresh = titlesToCatalogue(
      titles,
      account.lastImportedAt,
      removals.map(({ asin }) => asin),
      account.readAsins,
    )
    const removed = new Set<string>(removals.map(({ asin }) => asin))
    const returning = fresh.filter((title) => removed.has(title.asin)).map(({ asin }) => asin)
    const { links, linked, reads, asked } = await linksOf(
      owned,
      titles,
      fresh,
      account.lastImportedAt,
      now,
      store,
    )
    const moves = readingChangesFor(linked, titles, account.readAsins)
    const drawn = await drawnKindleBooksOf(linked, titles, asked, now)
    const acquired = toImportable(fresh, linked, reads, store).filter(
      (importable) => !importable.alreadyInLibrary,
    )

    const positions = await positionMovesOf(
      credentials,
      positionsToWatch(
        linked.filter((book) => !moves.includes(book.id)),
        titles,
      ),
    )

    const write = async () => {
      await linkAll(userId, links, now)
      await bulkSave(moves, async (bookId) => BookCommand.setStatus(userId, bookId, 'read', now))
      await bulkSave(
        await SeriesUseCase.filedAfterCatalogues(acquired.map(bookFrom)),
        async (book) => BookCommand.add(userId, book, now),
      )
      await bulkSave(positions, async ({ bookId, position }) =>
        BookCommand.recordKindlePosition(userId, bookId, position, now),
      )
      await bulkSave(drawn, async ({ bookId, format }) =>
        BookCommand.fileAsDrawn(userId, bookId, format, now),
      )
    }
    // A night with nothing new leaves the dashboard as it was.
    if (links.length + moves.length + acquired.length + positions.length + drawn.length > 0) {
      await AnalyticsUseCase.whileStale(userId, write)
    }
    await BookCommand.forgetSyncRemovals(userId, 'kindle', returning)

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
    budgetMs = NIGHTLY_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<KindleSyncRun> =>
    syncEveryConnectedReader(await KindleQuery.readersToSync(), {
      syncLibrary: (userId) => syncLibrary(userId),
      // Outside any request: their Découvrir projections are told here.
      afterSync: (userId) => DiscoveryCommand.recordLibraryChange([userId]),
      // Kept for the app, which offers to connect again.
      afterFailure: (userId) =>
        KindleCommand.recordFailure(userId).catch((error) =>
          logger.warn('Kindle sync failure could not be recorded', { error, userId }),
        ),
      logger,
      budgetMs,
      startedAt,
    })

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
      const named = await SeriesUseCase.filedAfterCatalogues(chosen.map(exportedBookFrom))
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
  lastPass: Date | undefined,
  now: Date,
  store: BookLanguage,
) => {
  const worth = titlesWorthMatching(owned, titles, fresh, lastPass)
  const asked = [...new Set([...fresh, ...worth])]
  const reads = await readingsOf(asked, now)
  const links = kindleLinksFor(owned, worth, reads, store)
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
  return { links, linked, reads, asked }
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
  const named = await SeriesUseCase.filedAfterCatalogues(chosen.map(bookFrom))
  await AnalyticsUseCase.whileStale(userId, () =>
    bulkSave(named, async (book) => {
      imported.push(await BookCommand.add(userId, book, now))
    }),
  )
  return imported
}

/** How many reading positions one reader's pass asks Amazon for at once, with
 *  up to SYNC_CONCURRENCY readers side by side: a handful, never a burst, for
 *  the firewall that already refuses some Kindle endpoints. */
const POSITIONS_IN_FLIGHT = 3

/** The positions that change something on their book, read from Amazon. A title
 *  Amazon will not answer for costs that book its night, not the pass. */
const positionMovesOf = async (
  credentials: KindleCredentials,
  books: ReadonlyArray<Book & { kindleAsin: KindleAsin }>,
) => {
  const found: { bookId: Book['id']; position: KindlePositionValue }[] = []
  await eachWithAtMostInFlight(books, POSITIONS_IN_FLIGHT, async (book) => {
    try {
      const position = await api.readingPosition(credentials, book.kindleAsin)
      if (position === undefined || !kindleMoveOf(book, position)) return
      found.push({ bookId: book.id, position: KindlePosition(position) })
    } catch (error) {
      logger.warn('Kindle position could not be read', { error, bookId: book.id })
    }
  })
  return found
}

/** One trip to Amazon: fresh cookies minted from the device, then the list —
 *  and the language of the store it lives on, which every edition Amazon names
 *  no language of is in. */
const fetchLibrary = async (
  userId: UserId,
): Promise<
  { titles: KindleTitle[]; store: BookLanguage; credentials: KindleCredentials } | 'not-connected'
> => {
  const connected = await connectedCredentials(userId)
  if (connected === 'not-connected') return connected
  return {
    titles: await api.library(connected.credentials),
    store: storeLanguageOf(connected.account.marketplace),
    credentials: connected.credentials,
  }
}

/** The reader's account and its credentials, opened: see `openedConnection`. */
const connectedCredentials = (userId: UserId) =>
  openedConnection(userId, {
    accountOf: KindleQuery.accountOf,
    openIfReadable: openReadableCredentials,
    disconnect: KindleCommand.disconnect,
    logger,
  })

const toImportable = (
  titles: readonly KindleTitle[],
  owned: readonly Book[],
  reads: ReadonlyMap<string, ReadKindleTitle>,
  store: BookLanguage,
  removed: ReadonlySet<string> = new Set(),
): ImportableKindleBook[] => {
  const shelf = shelfOf(owned)
  return markedRemovedByReader(
    titles.map((title) => importableFrom(title, shelf, reads, store)).filter(isPresent),
    removed,
  )
}

/** The Kindle books filed as prose whose title was read before the format was
 *  asked: read again, once, and the drawn ones among them. */
const drawnKindleBooksOf = async (
  owned: readonly Book[],
  titles: readonly KindleTitle[],
  askedTonight: readonly KindleTitle[],
  now: Date,
) => {
  const prose = owned.filter((book) => book.format === 'book' && book.kindleAsin)
  const asins = new Set<string>(prose.flatMap((book) => book.kindleAsin ?? []))
  const tonight = new Set(askedTonight.map((title) => title.asin))
  const held = titles.filter((title) => asins.has(title.asin) && !tonight.has(title.asin))
  const known = await KindleQuery.readTitles(held.map((title) => title.asin))
  const asked = new Set<string>(known.flatMap((read) => (read.format ? [read.asin] : [])))
  const unasked = held.filter((title) => !asked.has(title.asin))
  return unasked.length > 0 ? drawnBooksOf(prose, await readingsOf(unasked, now)) : []
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
  const unread = wanted.filter((title) => {
    const read = known.get(title.asin)
    return read?.amazonTitle !== title.title || read.format === undefined
  })
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
