import type { WriteBatch } from 'firebase-admin/firestore'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { mediaFor, recordJoinedBy, refreshedFacts } from '~/domain/book/business-rules'
import { BookCommand, type BookEdit, type NewBook } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type {
  BookId,
  ReadingNote,
  ReadingStatus,
  Recommendation,
  StarRating,
} from '~/domain/book/types'
import { isCoverGone, publishedCoverOf } from '~/domain/scan/published-cover'
import { ScanUseCase } from '~/domain/scan/use-case'
import { SeriesUseCase } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'

/** Every change a reader makes to their library, kept in step with the analytics
 *  view behind the home dashboard. The GraphQL layer writes books through here,
 *  never through `BookCommand` directly, so no write can forget the view.
 *
 *  The book and the view's stale flag land in one batch: the view can never look
 *  fresh while a book it does not reflect is already stored. */
export namespace BookUseCase {
  /** The saga is named as its catalogue names it, when it has one.
   *
   *  A book the reader already keeps on another medium — the paperback of a
   *  Kindle title, the Kindle copy of a paperback — joins that record rather
   *  than landing beside it: paper or screen, it is one book. */
  export const add = async (userId: UserId, input: NewBook) => {
    const [named] = await SeriesUseCase.filedAfterCatalogues([input])
    const format = named.format ?? 'book'
    // A recording joins nothing, so the library is not read for it.
    const joined =
      format !== 'audiobook' &&
      recordJoinedBy(await BookQuery.all(userId), {
        title: named.title,
        authors: named.authors ?? [],
        isbn13: named.isbn13,
        format,
        media: mediaFor(format, named.media),
        language: named.language,
        series: named.series,
      })
    return withAnalytics(userId, async (batch) => {
      if (!joined) return BookCommand.add(userId, named, undefined, batch)
      const book = await BookCommand.join(userId, joined.id, named, undefined, batch)
      if (book === 'not-found') throw new Error('a book just read from the library is gone')
      return book
    })
  }

  export const edit = (userId: UserId, bookId: BookId, edit: BookEdit) =>
    withAnalytics(userId, (batch) => BookCommand.edit(userId, bookId, edit, undefined, batch))

  /** Bring a record up to date: the book is looked up again, from what names
   *  it, as a volume the release watch announced is, and the facts that
   *  describe the work are rewritten from what was found — see
   *  `refreshedFacts`. Metered like any lookup: one scan, spent only once the
   *  model answered, and nothing written when it did not.
   *
   *  The published cover is sought by the ISBN the lookup found, then by the
   *  one already on the record, which the lookup may not have named. When
   *  neither has one, a stored cover that no longer loads is dropped, so the
   *  app draws its placeholder at once rather than failing on a dead link. */
  export const refresh = async (userId: UserId, bookId: BookId, language: Language) => {
    const book = await BookQuery.byId(userId, bookId)
    if (!book) return 'not-found' as const
    const seen = {
      recognized: true,
      title: book.title,
      authors: book.authors,
      format: book.format,
      publisher: book.publisher,
      language: book.language,
      subgenres: [],
    }
    // A volume is looked up as the volume it is, or a refresh of volume 2 of a
    // saga whose volumes are all titled after it brings back volume 1's ISBN.
    const found = book.series
      ? await ScanUseCase.lookUpVolume(userId, { ...seen, series: book.series }, language)
      : await ScanUseCase.lookUpEdition(userId, seen, language)
    if (typeof found === 'string' || 'failed' in found) return found
    const coverUrl =
      found.coverUrl ??
      (book.isbn13 && book.isbn13 !== found.isbn13
        ? await publishedCoverOf(book.isbn13)
        : undefined)
    const facts = refreshedFacts(book, { ...found, coverUrl }, language)
    const coverGone =
      !coverUrl &&
      book.publishedCoverUrl !== undefined &&
      (await isCoverGone(book.publishedCoverUrl))
    return edit(userId, bookId, coverGone ? { ...facts, publishedCoverUrl: undefined } : facts)
  }

  export const setStatus = (userId: UserId, bookId: BookId, status: ReadingStatus) =>
    withAnalytics(userId, (batch) =>
      BookCommand.setStatus(userId, bookId, status, undefined, batch),
    )

  export const rate = (userId: UserId, bookId: BookId, rating: StarRating) =>
    withAnalytics(userId, (batch) => BookCommand.rate(userId, bookId, rating, undefined, batch))

  export const unrate = (userId: UserId, bookId: BookId) =>
    withAnalytics(userId, (batch) => BookCommand.unrate(userId, bookId, undefined, batch))

  export const annotate = (userId: UserId, bookId: BookId, note: ReadingNote | undefined) =>
    withAnalytics(userId, (batch) => BookCommand.annotate(userId, bookId, note, undefined, batch))

  export const recommend = (
    userId: UserId,
    bookId: BookId,
    recommendation: Recommendation | undefined,
  ) =>
    withAnalytics(userId, (batch) =>
      BookCommand.recommend(userId, bookId, recommendation, undefined, batch),
    )

  export const setFavorite = (userId: UserId, bookId: BookId, favorite: boolean) =>
    withAnalytics(userId, (batch) =>
      BookCommand.setFavorite(userId, bookId, favorite, undefined, batch),
    )

  export const setHidden = (userId: UserId, bookId: BookId, hidden: boolean) =>
    withAnalytics(userId, (batch) =>
      BookCommand.setHidden(userId, bookId, hidden, undefined, batch),
    )

  export const remove = (userId: UserId, bookId: BookId) =>
    withAnalytics(userId, (batch) => BookCommand.remove(userId, bookId, batch))
}

// A book that was not found, or an edit refused, wrote nothing, so the view
// stays as it was.
const withAnalytics = <Outcome>(userId: UserId, write: (batch: WriteBatch) => Promise<Outcome>) =>
  AnalyticsUseCase.afterWrite(userId, write, wrote)

const wrote = (outcome: unknown): boolean => outcome !== 'not-found' && outcome !== 'no-author'
