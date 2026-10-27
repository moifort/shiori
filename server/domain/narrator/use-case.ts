import { AdminCommand } from '~/domain/admin/command'
import {
  inPageOrder,
  isPortraitWorthSeeking,
  standaloneBooksOf,
} from '~/domain/author/business-rules'
import type { PortraitUrl } from '~/domain/author/types'
import { BookQuery } from '~/domain/book/query'
import type { Book, NarratorName } from '~/domain/book/types'
import {
  isWorthDescribing,
  shelvedNarratorsOf,
  unshelvedNarratorOf,
} from '~/domain/narrator/business-rules'
import { NarratorCommand } from '~/domain/narrator/command'
import { NarratorQuery } from '~/domain/narrator/query'
import type { Narrator, NarratorKey, ShelvedNarrator } from '~/domain/narrator/types'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('narrator')

/** A narrator as their page draws them: what the library says, their face,
 *  and the reader's own heart on them, apart from the hearts their recordings
 *  and sagas carry. */
export type FollowedNarrator = ShelvedNarrator<Book> & {
  portraitUrl?: PortraitUrl
  favorite?: boolean
}

/** Everything a narrator's page draws, in one answer. */
export type NarratorPage = {
  narrator: FollowedNarrator
  /** What the world knows of them. Null when nobody has described them yet,
   *  or the model could not: the page still shows the reader's recordings. */
  catalogue: Narrator | null
  /** Nobody has described the narrator yet, and the page would not wait for
   *  the model: it draws the reader's recordings, and asks again. */
  awaitingCatalogue: boolean
  /** The reader's sagas heard in their voice, read into first. */
  sagas: FollowedSeries[]
  /** The reader's recordings of theirs outside any saga, listened ones first. */
  books: Book[]
}

export namespace NarratorUseCase {
  /** A narrator's page, their catalogue built the first time anybody opens
   *  it, as an author's is: one grounded call and a Wikipedia lookup, paid
   *  once for everyone, written in the language of whoever opened it.
   *
   *  A narrator the reader holds nothing of — named by a friend's recording —
   *  is drawn from the name `offered`. Null without it, or when it names
   *  somebody else. */
  export const page = async (
    userId: UserId,
    key: NarratorKey,
    language: Language,
    offered?: NarratorName,
    { waitForCatalogue = true }: { waitForCatalogue?: boolean } = {},
  ): Promise<NarratorPage | null> => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    const shelved =
      shelvedNarratorsOf(books, opinions).find((narrator) => narrator.key === key) ??
      (offered ? unshelvedNarratorOf<Book>(key, offered, new Date()) : null)
    if (!shelved) return null
    const [found, sagas, hearted] = await Promise.all([
      waitForCatalogue ? catalogueOf(shelved, language) : storedCatalogueOf(shelved),
      SeriesUseCase.followedAmong(userId, new Set(shelved.seriesIds)),
      NarratorQuery.favoriteKeys(userId),
    ])
    const awaitingCatalogue = found === 'unasked'
    const entry = found === 'unasked' ? null : found
    return {
      narrator: { ...shelved, portraitUrl: entry?.portraitUrl, favorite: hearted.has(key) },
      catalogue: entry?.cataloguedAt ? entry : null,
      awaitingCatalogue,
      sagas: inPageOrder(sagas),
      books: standaloneBooksOf(shelved.books),
    }
  }

  /** The stored entry, else one built now — unless the model failed on this
   *  narrator within the month. A described narrator with no portrait asks
   *  Wikipedia again, now and then, by their name. */
  const catalogueOf = async (
    shelved: ShelvedNarrator<Book>,
    language: Language,
  ): Promise<Narrator | null> => {
    const known = await NarratorQuery.byKey(shelved.key)
    if (isWorthDescribing(known, new Date())) return askTheWeb(known, shelved, language)
    return known && isPortraitWorthSeeking(known, new Date())
      ? NarratorCommand.seekPortrait(known)
      : known
  }

  /** The stored entry, as `catalogueOf` reads it, without asking the model:
   *  `unasked` when describing them is what would come next. */
  const storedCatalogueOf = async (
    shelved: ShelvedNarrator<Book>,
  ): Promise<Narrator | null | 'unasked'> => {
    const known = await NarratorQuery.byKey(shelved.key)
    if (isWorthDescribing(known, new Date())) return 'unasked'
    return known && isPortraitWorthSeeking(known, new Date())
      ? NarratorCommand.seekPortrait(known)
      : known
  }

  const askTheWeb = async (
    known: Narrator | null,
    shelved: ShelvedNarrator<Book>,
    language: Language,
  ): Promise<Narrator> => {
    const { narrator, usage } = await NarratorCommand.catalogueFromWeb(
      known,
      shelved.key,
      shelved.name,
      language,
    )
    // Telemetry: the catalogue is already built, so a failed counter write is
    // logged rather than turned into an error the reader has to read.
    if (usage)
      await AdminCommand.recordCatalogueUsage(usage).catch((error) =>
        logger.warn('AI usage not recorded', { error }),
      )
    return narrator
  }
}
