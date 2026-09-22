import { AdminCommand } from '~/domain/admin/command'
import { AnalyticsCommand } from '~/domain/analytics/command'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { BookLanguage } from '~/domain/book/types'
import { Scan } from '~/domain/scan'
import type { ScanLanguage } from '~/domain/scan/types'
import { cataloguesOf } from '~/domain/series/business-rules'
import { SeriesQuery } from '~/domain/series/query'
import type { Series, SeriesId } from '~/domain/series/types'
import { SeriesOpinionCommand } from '~/domain/series-opinion/command'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { atomically } from '~/utils/firestore'

const logger = createLogger('series')

export namespace SeriesUseCase {
  /** Removes a saga from the reader's library: every volume they hold, and what
   *  they made of it. The shared catalogue stays, as it belongs to nobody.
   *
   *  One batch, so the library never shows half a saga. Returns how many books
   *  went; zero when the reader held none. */
  /** Take a saga off the shelf: every volume the reader holds, or only those
   *  of one edition when `edition` names a language — the Series tab shows a
   *  saga held in two languages as two rows, and the reader removes the row
   *  they see. Their opinion is of the work, not of an edition, so it is
   *  forgotten only once no volume of the saga remains. */
  export const removeFromLibrary = async (
    userId: UserId,
    seriesId: SeriesId,
    edition?: BookLanguage,
  ): Promise<number> => {
    const removed = await atomically(async (batch) => {
      const { removed, remaining } = await BookCommand.removeSeries(
        userId,
        seriesId,
        edition,
        batch,
      )
      if (remaining === 0) await SeriesOpinionCommand.forget(userId, seriesId, batch)
      if (removed > 0) AnalyticsCommand.markStale(userId, batch)
      return removed
    })
    if (removed > 0) await AnalyticsUseCase.refreshAfterWrite(userId)
    return removed
  }

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

    const { series, usage } = await Scan.catalogueSeries(
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
        logger.warn(`AI usage not recorded: ${error}`),
      )
    // The dashboard measures a saga against its catalogue, and this saga had
    // none until now: rebuilt here, or the progress bar would wait for the next
    // unrelated book write to appear.
    if (series) await AnalyticsUseCase.refreshAfterWrite(userId)
    return series ?? null
  }
}
