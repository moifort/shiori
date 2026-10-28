import type { WriteBatch } from 'firebase-admin/firestore'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import {
  coverCandidatesOf,
  mediaFor,
  mendedNames,
  recordJoinedBy,
  refreshedFacts,
} from '~/domain/book/business-rules'
import { BookCommand, type BookEdit, type NewBook } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type {
  Book,
  BookFormat,
  BookId,
  BookLanguage,
  BookMedium,
  ChosenCover,
  CoverChoice,
  PageCount,
  Publisher,
  ReadingNote,
  ReadingStatus,
  Recommendation,
  StarRating,
} from '~/domain/book/types'
import { DEFAULT_BOOK_LANGUAGE } from '~/domain/book/types'
import { exhausted } from '~/domain/quota/business-rules'
import { QuotaCommand } from '~/domain/quota/command'
import { QuotaQuery } from '~/domain/quota/query'
import {
  isbnCoversOf,
  isCoverGone,
  isImageAt,
  otherEditionCoversOf,
  publishedCoverOf,
  shelfCoverOf,
} from '~/domain/scan/published-cover'
import type { ScanResult } from '~/domain/scan/types'
import { ScanUseCase } from '~/domain/scan/use-case'
import { seriesKeyOf } from '~/domain/series/primitives'
import type { SeriesName, VolumeNumber } from '~/domain/series/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import { objectStore } from '~/system/object-store'

/** A book ticked on a shelf photo, as the checklist left it: what its spine
 *  printed, with the title and authors the reader may have corrected. */
export type ShelfPick = {
  title: BookTitle
  authors: AuthorName[]
  publisher?: Publisher
  /** The edition's: printed on the spine, else the language of the app. */
  language: BookLanguage
  format?: BookFormat
  media?: BookMedium[]
  seriesName?: SeriesName
  volume?: VolumeNumber
}

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

  /** Catalogue a book ticked on a shelf photo from what its spine printed, with
   *  no model call: a cover found by title through Open Library, the saga keyed
   *  from its printed name, and the record flagged until its first opening
   *  describes it (`describe`). Spends one scan once saved, as describing it
   *  up front did, so the allowance means what it meant; refused once nothing
   *  is left. Like any addition, a book the reader keeps on another medium
   *  joins that record. */
  export const addFromShelf = async (userId: UserId, pick: ShelfPick) => {
    const { plan, quota, credit } = await QuotaQuery.allowanceOf(userId)
    if (exhausted(plan, quota, credit)) return 'quota-exhausted' as const
    const format = pick.format ?? 'book'
    const author = pick.authors[0]
    // Without an author a title alone is too loose a search to trust a cover from.
    const publishedCoverUrl = author
      ? await shelfCoverOf({
          title: pick.title,
          author,
          volume: pick.volume,
          language: pick.language,
        })
      : undefined
    // Keyed as a scan keys it; without an author there is no stable key.
    const series =
      pick.seriesName && author
        ? {
            saga: seriesKeyOf(pick.seriesName, author, format),
            name: pick.seriesName,
            volume: pick.volume,
            kind: 'main' as const,
          }
        : undefined
    const book = await add(userId, {
      title: pick.title,
      authors: pick.authors,
      format,
      media: pick.media,
      publisher: pick.publisher,
      language: pick.language,
      series,
      publishedCoverUrl,
      awaitingDescription: true,
    })
    await QuotaCommand.record(userId, plan)
    return book
  }

  /** Describe a book added from a shelf photo, the first time its page is
   *  opened: looked up as a refresh looks it up, its facts written, the flag
   *  cleared. Free — the scan was spent on adding it. A book not flagged comes
   *  back as it is, with no model call: this is never a free refresh. A failed
   *  lookup writes nothing and leaves the flag, for the next opening to retry. */
  export const describe = async (userId: UserId, bookId: BookId, language: Language) => {
    const book = await BookQuery.byId(userId, bookId)
    if (!book) return 'not-found' as const
    if (!book.awaitingDescription) return book
    const found = await ScanUseCase.describeOnFirstOpening(userId, seenOf(book), language)
    if (typeof found === 'string' || 'failed' in found) return found
    return rewrittenFrom(userId, book, found, language)
  }

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
    const seen = seenOf(book)
    // A volume is looked up as the volume it is, or a refresh of volume 2 of a
    // saga whose volumes are all titled after it brings back volume 1's ISBN.
    const found = book.series
      ? await ScanUseCase.lookUpVolume(userId, { ...seen, series: book.series }, language)
      : await ScanUseCase.lookUpEdition(userId, seen, language)
    if (typeof found === 'string' || 'failed' in found) return found
    return rewrittenFrom(userId, book, found, language)
  }

  /** The covers the reader may pick for a book, the one drawn now first:
   *  what the record holds, and what Amazon and Open Library have for its
   *  ISBN and for its other editions in its language. Free — no model call,
   *  no scan spent — and a source that fails is a cover not offered. */
  export const coverChoices = async (
    userId: UserId,
    bookId: BookId,
  ): Promise<CoverChoice[] | 'not-found'> => {
    const book = await BookQuery.byId(userId, bookId)
    if (!book) return 'not-found'
    const author = book.authors[0]
    const [byIsbn, otherEditions] = await Promise.all([
      book.isbn13 ? isbnCoversOf(book.isbn13) : {},
      // Without an author a title alone is too loose a search to trust a cover from.
      author
        ? otherEditionCoversOf({
            title: book.title,
            author,
            volume: book.series?.volume,
            language: book.language ?? DEFAULT_BOOK_LANGUAGE,
            isbn13: book.isbn13,
          })
        : [],
    ])
    const { coverPath } = book
    return Promise.all(
      coverCandidatesOf(book, { ...byIsbn, otherEditions }).map(
        async (candidate): Promise<CoverChoice> => {
          if (candidate.source !== 'photo') return candidate
          if (!coverPath) throw new Error('a photo is offered only for a book that has one')
          return { ...candidate, url: await objectStore().downloadUrl(coverPath) }
        },
      ),
    )
  }

  /** Draw the book with the cover the reader picked. An address must serve an
   *  image: a pasted link to a shop's page would leave the placeholder for good. */
  export const chooseCover = async (userId: UserId, bookId: BookId, cover: ChosenCover) => {
    if (cover.source === 'url' && !(await isImageAt(cover.url))) return 'not-an-image' as const
    return withAnalytics(userId, (batch) =>
      BookCommand.chooseCover(userId, bookId, cover, undefined, batch),
    )
  }

  export const setStatus = (userId: UserId, bookId: BookId, status: ReadingStatus) =>
    withAnalytics(userId, (batch) =>
      BookCommand.setStatus(userId, bookId, status, undefined, batch),
    )

  export const recordPage = (userId: UserId, bookId: BookId, page: PageCount) =>
    withAnalytics(userId, (batch) => BookCommand.recordPage(userId, bookId, page, undefined, batch))

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

/** What names a book, to look it up again. */
const seenOf = (book: Book): ScanResult => ({
  recognized: true,
  title: book.title,
  authors: book.authors,
  format: book.format,
  publisher: book.publisher,
  language: book.language,
  series: book.series,
  // Said so a lookup that finds no synopsis knows the record keeps its own.
  synopsis: book.synopsis,
  subgenres: [],
})

/** The facts that describe the work rewritten from what a lookup found — see
 *  `refreshedFacts` — and the book described from then on. The published cover
 *  is sought by the ISBN the lookup found, then by the one already on the
 *  record, which the lookup may not have named. When neither has one, a stored
 *  cover that no longer loads is dropped, so the app draws its placeholder at
 *  once rather than failing on a dead link. */
const rewrittenFrom = async (userId: UserId, book: Book, found: ScanResult, language: Language) => {
  const coverUrl =
    found.coverUrl ??
    (book.isbn13 && book.isbn13 !== found.isbn13 ? await publishedCoverOf(book.isbn13) : undefined)
  const facts = refreshedFacts(book, { ...found, coverUrl }, language)
  const coverGone =
    !coverUrl && book.publishedCoverUrl !== undefined && (await isCoverGone(book.publishedCoverUrl))
  return BookUseCase.edit(userId, book.id, {
    ...mendedNames(book, found),
    ...facts,
    ...(coverGone ? { publishedCoverUrl: undefined } : {}),
    awaitingDescription: undefined,
  })
}

// A book that was not found, or an edit refused, wrote nothing, so the view
// stays as it was.
const withAnalytics = <Outcome>(userId: UserId, write: (batch: WriteBatch) => Promise<Outcome>) =>
  AnalyticsUseCase.afterWrite(userId, write, wrote)

const wrote = (outcome: unknown): boolean =>
  outcome !== 'not-found' &&
  outcome !== 'no-author' &&
  outcome !== 'no-photo' &&
  outcome !== 'audiobook' &&
  outcome !== 'past-the-end'
