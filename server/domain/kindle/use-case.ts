import { AnalyticsCommand } from '~/domain/analytics/command'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { bookFrom, importablesFrom } from '~/domain/kindle/business-rules'
import type { ImportableKindleBook, UnreadableExport } from '~/domain/kindle/types'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { atomically, bulkSave } from '~/utils/firestore'

const logger = createLogger('kindle')

/** Cataloguing a Kindle library from the file Amazon hands its customers.
 *
 *  There is no connection to open and no sync to run: Amazon publishes no
 *  Kindle library API, and the Audible credentials reach nothing here. What
 *  exists is the data export every customer can ask for, which arrives as a
 *  CSV, so that is what this reads.
 *
 *  The import proposes and the reader disposes, exactly as a scan does. Reading
 *  the file saves nothing; the app lists what it found, the reader ticks, and
 *  only then is anything written. The chosen titles are cut from a second read
 *  of the same file rather than from records the app composed, so every stored
 *  field comes from the export. */
export namespace KindleUseCase {
  /** What the file holds, ticked against the library it would join. Saves
   *  nothing. */
  export const read = async (
    userId: UserId,
    csv: string,
  ): Promise<ImportableKindleBook[] | UnreadableExport> =>
    importablesFrom(csv, await BookQuery.all(userId))

  /** Catalogue the titles the reader ticked.
   *
   *  The file is read again rather than trusted from the app: the keys say
   *  which rows were wanted, the export says what they are. A title already on
   *  the shelf is skipped however it was ticked — the picker shows those
   *  untappable, and a second request must not be able to duplicate them.
   *
   *  The analytics view is marked stale before the first book lands, so it can
   *  never look fresh over books it does not count. */
  export const importBooks = async (
    userId: UserId,
    csv: string,
    keys: readonly string[],
  ): Promise<Book[] | UnreadableExport> => {
    const found = await read(userId, csv)
    if (found === 'no-title-column') return found

    const wanted = new Set(keys)
    const chosen = found.filter(
      (importable) => wanted.has(importable.key) && !importable.alreadyInLibrary,
    )

    const imported: Book[] = []
    if (chosen.length > 0) {
      await atomically(async (batch) => AnalyticsCommand.markStale(userId, batch))
      await bulkSave(chosen, async (importable) => {
        imported.push(await BookCommand.add(userId, bookFrom(importable)))
      })
    }

    // Same contract as a book write: a failed rebuild leaves the view stale for
    // the next read to redo, it does not fail the import that already landed.
    try {
      await AnalyticsCommand.refresh(userId)
    } catch (error) {
      logger.warn('dashboard rebuild failed after import, left stale', { error, userId })
    }
    return imported
  }
}
