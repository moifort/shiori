import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { recordJoinedBy } from '~/domain/book/business-rules'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { Book, BookId } from '~/domain/book/types'
import {
  bookFrom,
  completionOf,
  destinationOf,
  previewOf,
  rowsOf,
  verdictsOf,
} from '~/domain/goodreads/business-rules'
import { GoodreadsCommand } from '~/domain/goodreads/command'
import { GoodreadsQuery } from '~/domain/goodreads/query'
import type {
  GoodreadsChoices,
  GoodreadsImport,
  GoodreadsImportOutcome,
  GoodreadsPreview,
  UnreadableGoodreadsExport,
} from '~/domain/goodreads/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import type { UserId } from '~/domain/shared/types'
import { MAX_WISHES, wishIdOf } from '~/domain/wish/business-rules'
import { WishCommand } from '~/domain/wish/command'
import { WishQuery } from '~/domain/wish/query'
import { createLogger } from '~/system/logger'
import { eachWithAtMostInFlight } from '~/utils/concurrency'

const logger = createLogger('goodreads')

/** How many covers one pass seeks: each is up to three free lookups (Amazon,
 *  Open Library, ePagine), so forty stay well inside a request's time. */
export const COVERS_PER_PASS = 40

/** How many cover lookups run side by side. */
const COVERS_IN_FLIGHT = 6

/** How many rows are written side by side: Firestore takes far more, the
 *  friend and wish lookups each write makes are what this bounds. */
const WRITES_IN_FLIGHT = 10

export namespace GoodreadsUseCase {
  /** What an export holds, against the library it would join. Saves nothing,
   *  calls no paid service: a file read and compared with the shelf. */
  export const preview = async (
    userId: UserId,
    csv: string,
  ): Promise<GoodreadsPreview | UnreadableGoodreadsExport> => {
    const rows = rowsOf(csv)
    if (typeof rows === 'string') return rows
    return previewOf(verdictsOf(rows, await BookQuery.all(userId), BookQuery.languageOfIsbn))
  }

  /** Catalogue the rows the reader ticked, from a second read of the same file:
   *  the client sends keys and choices, every stored field comes from the export.
   *
   *  A new row becomes a book, or a wish when `to-read` goes to the wishlist; a
   *  held row, or an uncertain one the reader called the same book, completes
   *  the record it matches with what that record lacks. A copy on another
   *  medium joins its record as any arrival does. Nothing paid is called: the
   *  saga is filed after the shared catalogues already known, and covers are
   *  sought afterwards, a pass at a time (`seekCovers`). Running the same
   *  export twice adds nothing the first run added. */
  export const importExport = async (
    userId: UserId,
    csv: string,
    choices: GoodreadsChoices,
    now = new Date(),
  ): Promise<GoodreadsImportOutcome | UnreadableGoodreadsExport> => {
    const found = await preview(userId, csv)
    if (typeof found === 'string') return found
    const wanted = new Set(choices.keys)
    const same = new Set(choices.sameBooks)
    const rows = found.rows.filter((row) => wanted.has(row.key))

    const library = await BookQuery.all(userId)
    const owned = new Map(library.map((book) => [book.id, book]))
    const wishes = await WishQuery.byUser(userId)
    const wishIds = new Set(wishes.map((wish) => wish.id))
    let room = MAX_WISHES - wishes.length
    // Every saga filed after the shared catalogues in one read, not one per row.
    const statusOf = (row: (typeof rows)[number]) => {
      const destination = destinationOf(row, choices)
      return destination === 'wish' ? 'to-read' : destination
    }
    const named = await SeriesUseCase.filedAfterCatalogues(
      rows.map((row) => bookFrom(row, statusOf(row), choices)),
    )
    const namedOf = new Map(rows.map((row, index) => [row.key, named[index]]))

    const created: BookId[] = []
    let completed = 0
    let wished = 0

    // The export holds one row per title and author, so no two rows join one
    // record: they are written side by side.
    await AnalyticsUseCase.whileStale(userId, () =>
      eachWithAtMostInFlight(rows, WRITES_IN_FLIGHT, async (row) => {
        const held =
          row.heldBookId && (row.verdict === 'held' || same.has(row.key))
            ? owned.get(row.heldBookId)
            : undefined
        const destination = destinationOf(row, choices)
        const status = statusOf(row)

        if (held) {
          const completion = completionOf(held, bookFrom(row, status, choices))
          if (!completion) return
          const joined = await BookCommand.join(userId, held.id, completion, now)
          if (joined !== 'not-found') completed += 1
          return
        }

        if (destination === 'wish' && room > 0) {
          const id = wishIdOf(userId, row)
          if (wishIds.has(id)) return
          wishIds.add(id)
          room -= 1
          await WishCommand.save({
            id,
            userId,
            title: row.title,
            authors: row.authors,
            format: row.format,
            language: row.language,
            series: row.series,
            coverUrl: row.coverGuess,
            isbn13: row.isbn13,
            origin: { kind: 'goodreads' },
            wishedAt: row.addedOn ?? now,
          })
          wished += 1
          return
        }

        // A full wishlist sends the rest to the pile rather than losing them.
        const input = { ...(namedOf.get(row.key) ?? bookFrom(row, status, choices)), status }
        const joined = recordJoinedBy(library, {
          title: input.title,
          authors: input.authors ?? [],
          isbn13: input.isbn13,
          format: input.format ?? 'book',
          media: input.media ?? ['print'],
          language: input.language,
          series: input.series,
        })
        if (joined) {
          const book = await BookCommand.join(userId, joined.id, input, now)
          if (book !== 'not-found') completed += 1
          return
        }
        const book = await BookCommand.add(userId, input, now)
        owned.set(book.id, book)
        created.push(book.id)
      }),
    )

    const pendingCovers = created.filter((id) => {
      const book = owned.get(id)
      return book !== undefined && needsCover(book)
    })
    await GoodreadsCommand.recordImport({
      userId,
      importedAt: now,
      imported: created.length,
      completed,
      wished,
      pendingCovers,
      withoutCover: 0,
    })
    return { imported: created.length, completed, wished, pendingCovers: pendingCovers.length }
  }

  /** Seek the published covers of the books the last import wrote, a pass at a
   *  time: the app calls it again while its screen is open, and a book no source
   *  has keeps the app's typeset stand-in. Free sources only. Answers how many
   *  books are still waiting. */
  export const seekCovers = async (
    userId: UserId,
    now = new Date(),
  ): Promise<{ remaining: number; found: number }> => {
    const record = await GoodreadsQuery.lastImport(userId)
    if (!record || record.pendingCovers.length === 0) return { remaining: 0, found: 0 }
    const batch = record.pendingCovers.slice(0, COVERS_PER_PASS)
    let found = 0
    let missing = 0
    await eachWithAtMostInFlight(batch, COVERS_IN_FLIGHT, async (bookId) => {
      const book = await BookQuery.byId(userId, bookId)
      if (!book?.isbn13 || !needsCover(book)) return
      const cover = await BookQuery.publishedCoverOf(book.isbn13)
      if (!cover) {
        missing += 1
        return
      }
      const edited = await BookCommand.edit(userId, bookId, { publishedCoverUrl: cover }, now)
      if (typeof edited === 'string') logger.warn('cover not written', { outcome: edited, bookId })
      else found += 1
    })
    const pendingCovers = record.pendingCovers.slice(batch.length)
    await GoodreadsCommand.recordImport({
      ...record,
      pendingCovers,
      withoutCover: record.withoutCover + missing,
    })
    return { remaining: pendingCovers.length, found }
  }

  /** The last import, for the settings page. */
  export const lastImport = (userId: UserId): Promise<GoodreadsImport | undefined> =>
    GoodreadsQuery.lastImport(userId)
}

/** A book that would still draw the app's stand-in: no cover of any kind, and
 *  an ISBN to seek one by. */
const needsCover = (book: Book): boolean =>
  book.isbn13 !== undefined &&
  !book.publishedCoverUrl &&
  !book.kindleCoverUrl &&
  !book.coverPath &&
  !book.chosenCover
