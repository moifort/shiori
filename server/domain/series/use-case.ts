import { AdminCommand } from '~/domain/admin/command'
import { AnalyticsCommand } from '~/domain/analytics/command'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import { Scan } from '~/domain/scan'
import type { ScanLanguage } from '~/domain/scan/types'
import { SeriesQuery } from '~/domain/series/query'
import type { Series, SeriesId } from '~/domain/series/types'
import { SeriesOpinionCommand } from '~/domain/series-opinion/command'
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
  export const removeFromLibrary = async (userId: UserId, seriesId: SeriesId): Promise<number> => {
    const removed = await atomically(async (batch) => {
      const count = await BookCommand.removeSeries(userId, seriesId, batch)
      await SeriesOpinionCommand.forget(userId, seriesId, batch)
      if (count > 0) AnalyticsCommand.markStale(userId, batch)
      return count
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
   *  Null when the reader holds no volume of the saga, since there is then
   *  nothing to ask about, and when the model fails or finds no volumes: the
   *  next opening tries again. */
  export const describe = async (
    userId: UserId,
    seriesId: SeriesId,
    language: ScanLanguage,
  ): Promise<Series | null> => {
    const known = await SeriesQuery.byId(seriesId)
    if (known) return known

    const volume = (await BookQuery.bySeries(userId, seriesId)).find(
      (book) => book.series && book.authors.length > 0,
    )
    if (!volume?.series) return null

    const { series, usage } = await Scan.catalogueSeries(
      seriesId,
      volume.series.name,
      volume.authors[0],
      language,
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
