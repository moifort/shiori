import { AdminCommand } from '~/domain/admin/command'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { inSagaOrder, readVolumeNumbersOf, shelfDateOf } from '~/domain/book/business-rules'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { Book, BookLanguage, Genre } from '~/domain/book/types'
import { ScanCommand } from '~/domain/scan/command'
import type { ScanLanguage } from '~/domain/scan/types'
import {
  cataloguesOf,
  type FollowedSaga,
  followedSagasOf,
  followedStateOf,
  genreOf,
  inTabOrder,
  matchingFilter,
  progressOf,
} from '~/domain/series/business-rules'
import { SeriesQuery } from '~/domain/series/query'
import type { Series, SeriesId, SeriesName, SeriesState } from '~/domain/series/types'
import { editionUnfollowed } from '~/domain/series-opinion/business-rules'
import { SeriesOpinionCommand } from '~/domain/series-opinion/command'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import { Count, Year } from '~/domain/shared/primitives'
import type { AuthorName, Count as CountValue, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('series')

/** A saga the reader follows.
 *
 *  Its identity comes from the reader's own books, not from the catalogue: a
 *  saga named by an Audible import or by a book added by hand has no catalogue
 *  document, and reading the catalogue first made every one of those disappear
 *  from the Series tab.
 *
 *  So `catalogue` is what may be missing, never the saga. */
export type FollowedSeries = {
  id: SeriesId
  name: SeriesName
  author?: AuthorName
  language?: BookLanguage
  genre?: Genre
  catalogue: Series | null
  opinion: SeriesOpinion | null
  state: SeriesState | null
  progress: SagaProgress | null
  ownedCount: CountValue
  /** The owned volumes, in the order the saga itself runs. */
  books: Book[]
  /** The latest date any owned volume is shelved on: what the tab is ordered
   *  and cut into month sections by. */
  shelvedAt: Date
}

export type SagaProgress = { readCount: number; totalCount: number }

export namespace SeriesUseCase {
  /** Every saga the reader follows, one row per saga and language: a reader who
   *  holds Dune in French and in English follows two rows, because those are
   *  two sets of books.
   *
   *  Taken from the books, then matched against the catalogue in one getAll and
   *  against the reader's opinions in one scan — never a lookup per saga. */
  export const followed = async (userId: UserId): Promise<FollowedSeries[]> => {
    const shelf = await shelfOf(userId)
    return described(shelf, shelf.sagas)
  }

  /** One row of the Series tab — a saga in one edition, `language` absent for
   *  the volumes that record none — as the page it sits in would draw it: what
   *  the tab asks again once the reader has changed that saga, rather than a
   *  page of every saga to find it in. Only its own catalogue is read.
   *
   *  Null when the reader no longer holds a volume of that edition. */
  export const followedOne = async (
    userId: UserId,
    seriesId: SeriesId,
    language?: BookLanguage,
  ): Promise<FollowedSeries | null> => {
    const shelf = await shelfOf(userId)
    const saga = shelf.sagas.find((saga) => saga.id === seriesId && saga.language === language)
    if (!saga) return null
    const [row] = await described(shelf, [saga])
    return row ?? null
  }

  /** One page of the Series tab, newest first on `shelvedAt`, narrowed to the
   *  hearted sagas or to one state.
   *
   *  Without a state filter, which sagas a page holds depends on the books and
   *  the opinions alone — a saga set aside is the reader's own flag — so only
   *  the page's sagas have their catalogue read. A state filter needs every
   *  saga's state, and so every catalogue. */
  export const followedPage = async (
    userId: UserId,
    page: { limit: number; offset: number },
    filter: { favorite?: boolean; state?: SeriesState },
  ): Promise<{ items: FollowedSeries[]; hasMore: boolean }> => {
    const shelf = await shelfOf(userId)
    if (filter.state !== undefined) {
      const all = (await described(shelf, shelf.sagas)).map((saga) => ({
        ...saga,
        favorite: saga.opinion?.favorite === true,
      }))
      return pageOf(inTabOrder(matchingFilter(all, filter)), page)
    }
    const kept = matchingFilter(
      shelf.sagas.map((saga) => ({ ...saga, state: saga.unfollowed ? 'unfollowed' : null })),
      filter,
    )
    const { items, hasMore } = pageOf(inTabOrder(kept), page)
    return { items: await described(shelf, items), hasMore }
  }

  /** Take a saga off the shelf: every volume the reader holds, or only those
   *  of one edition when `edition` names a language — the Series tab shows a
   *  saga held in two languages as two rows, and the reader removes the row
   *  they see. Their opinion is of the work, not of an edition, so it is
   *  forgotten only once no volume of the saga remains. The shared catalogue
   *  stays, as it belongs to nobody.
   *
   *  One batch, so the library never shows half a saga. Returns how many books
   *  went; zero when the reader held none. */
  export const removeFromLibrary = (
    userId: UserId,
    seriesId: SeriesId,
    edition?: BookLanguage,
  ): Promise<number> =>
    AnalyticsUseCase.afterWrite(
      userId,
      async (batch) => {
        const { removed, remaining } = await BookCommand.removeSeries(
          userId,
          seriesId,
          edition,
          batch,
        )
        if (remaining === 0) await SeriesOpinionCommand.forget(userId, seriesId, batch)
        return removed
      },
      (removed) => removed > 0,
    )

  /** One saga's catalogue, built the first time somebody asks for it.
   *
   *  A scan catalogues the saga of every volume it reads, but an Audible import
   *  names sagas without describing them, and a scan's catalogue call can fail.
   *  Either way the saga sat in the Series tab with a screen saying it was not
   *  catalogued, for good. So the screen catalogues it, from the name and the
   *  author of a volume the reader holds: one grounded call, paid once for
   *  everyone, and only for sagas somebody actually opens — an import of a whole
   *  library must not pay one call per saga inside a single request.
   *
   *  `edition` is the language of the row the reader opened, for a saga they
   *  hold in more than one: the catalogue titles its volumes as that edition
   *  does. Absent, the edition of whichever volume they hold answers.
   *
   *  A saga the reader counted themselves answers with a provisional catalogue
   *  drawn from that count, and the model is not asked: `recatalogue` is how
   *  they ask for the world's.
   *
   *  Null when the reader holds no volume of the saga, since there is then
   *  nothing to ask about, and when the model fails or finds no volumes: the
   *  next opening tries again. */
  export const describe = async (
    userId: UserId,
    seriesId: SeriesId,
    language: ScanLanguage,
    edition?: BookLanguage,
  ): Promise<Series | null> => {
    const known = await SeriesQuery.byId(seriesId)
    if (known) return known
    // The reader counted the volumes themselves: their spine is drawn from
    // that, and the world is only asked again when they ask for it — every
    // opening would otherwise wait on a model call that already failed once.
    const opinion = await SeriesOpinionQuery.of(userId, seriesId)
    if (opinion?.volumeCount !== undefined) {
      const provisional = cataloguesOf(
        await BookQuery.bySeries(userId, seriesId),
        [],
        [opinion],
      ).get(seriesId)
      if (provisional) return provisional
    }
    return catalogueFromLibrary(userId, seriesId, language, edition)
  }

  /** The catalogue asked of the world again, replacing the stored one.
   *
   *  A catalogue is written once and read by everyone, so a volume announced
   *  after that call never showed, and a catalogue built in the wrong language
   *  never got another chance. The reader asks for a fresh one; the write
   *  replaces the stale list for everyone, as the command allows.
   *
   *  Null when the reader holds no volume of the saga, and when the model fails
   *  or finds no volumes — the previous catalogue is then left untouched, so a
   *  refresh never costs the reader what they had. */
  export const recatalogue = async (
    userId: UserId,
    seriesId: SeriesId,
    language: ScanLanguage,
    edition?: BookLanguage,
  ): Promise<Series | null> => catalogueFromLibrary(userId, seriesId, language, edition)

  const catalogueFromLibrary = async (
    userId: UserId,
    seriesId: SeriesId,
    language: ScanLanguage,
    edition: BookLanguage | undefined,
  ): Promise<Series | null> => {
    const held = (await BookQuery.bySeries(userId, seriesId)).filter(
      (book) => book.series && book.authors.length > 0,
    )
    // The edition the reader opened first, then any volume that says its
    // language, then whatever they hold.
    const volume =
      held.find((book) => edition !== undefined && book.language === edition) ??
      held.find((book) => book.language !== undefined) ??
      held[0]
    if (!volume?.series) return null

    const { series, usage } = await ScanCommand.catalogueSeries(
      seriesId,
      volume.series.name,
      volume.authors[0],
      language,
      volume.language,
    )
    // Telemetry: the catalogue is already built, so a failed counter write is
    // logged rather than turned into an error the reader has to read.
    if (usage)
      await AdminCommand.recordCatalogueUsage(usage).catch((error) =>
        logger.warn('AI usage not recorded', { error }),
      )
    // The dashboard measures a saga against its catalogue, and this saga had
    // none until now: flagged here, or the progress bar would wait for the next
    // unrelated book write to appear.
    if (series) await AnalyticsUseCase.markStale(userId)
    return series ?? null
  }
}

/** A saga as the books and the opinions describe it, before any catalogue is
 *  read: enough to filter and order the Series tab. */
type ShelvedSaga = FollowedSaga<Book> & {
  opinion: SeriesOpinion | null
  favorite: boolean
  unfollowed: boolean
  shelvedAt: Date
}

type Shelf = { books: Book[]; opinions: SeriesOpinion[]; sagas: ShelvedSaga[] }

const shelfOf = async (userId: UserId): Promise<Shelf> => {
  const [books, opinions] = await Promise.all([
    BookQuery.all(userId),
    SeriesOpinionQuery.all(userId),
  ])
  const byId = new Map(opinions.map((opinion) => [opinion.seriesId, opinion]))
  const sagas = followedSagasOf(books).map((saga) => {
    const opinion = byId.get(saga.id) ?? null
    return {
      ...saga,
      opinion,
      favorite: opinion?.favorite === true,
      unfollowed: editionUnfollowed(opinion, saga.language),
      shelvedAt: new Date(Math.max(...saga.books.map((book) => shelfDateOf(book).getTime()))),
    }
  })
  return { books, opinions, sagas }
}

/** The sagas given, with what the catalogue says of them: their catalogue in
 *  one getAll, and the state and progress it decides. Every edition's volumes
 *  of those sagas are passed on, since a count the reader typed draws its
 *  spine from all of them. */
const described = async (
  shelf: Shelf,
  sagas: readonly ShelvedSaga[],
): Promise<FollowedSeries[]> => {
  const ids = new Set(sagas.map((saga) => saga.id))
  const catalogued = cataloguesOf(
    shelf.books.filter((book) => book.series && ids.has(book.series.id)),
    await SeriesQuery.byIds([...ids]),
    shelf.opinions,
  )
  const currentYear = Year(new Date().getUTCFullYear())
  return sagas.map((saga) => {
    const catalogue = catalogued.get(saga.id) ?? null
    const read = readVolumeNumbersOf(saga.books)
    return {
      id: saga.id,
      name: saga.name,
      author: saga.author,
      language: saga.language,
      genre: genreOf(saga.books),
      catalogue,
      opinion: saga.opinion,
      state: followedStateOf(
        saga.books.map((book) => book.status),
        catalogue,
        read,
        currentYear,
        saga.unfollowed,
        { language: saga.language },
      ),
      progress: catalogue
        ? progressOf(catalogue, read, currentYear, { language: saga.language })
        : null,
      ownedCount: Count(saga.books.length),
      books: inSagaOrder(saga.books),
      shelvedAt: saga.shelvedAt,
    }
  })
}

const pageOf = <Row>(rows: readonly Row[], page: { limit: number; offset: number }) => ({
  items: rows.slice(page.offset, page.offset + page.limit),
  hasMore: page.offset + page.limit < rows.length,
})
