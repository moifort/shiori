import { match } from 'ts-pattern'
import { AdminCommand } from '~/domain/admin/command'
import {
  heartedFirst,
  inActivityOrder,
  inAuthorOrder,
  inNameOrder,
  inPageOrder,
  isPortraitWorthSeeking,
  standaloneBooksOf,
} from '~/domain/author/business-rules'
import type { PortraitChoice, PortraitUrl } from '~/domain/author/types'
import type { AuthorOrder } from '~/domain/author/use-case'
import { CoverUrl } from '~/domain/book/primitives'
import { BookQuery } from '~/domain/book/query'
import type { Book, NarratorName } from '~/domain/book/types'
import { CatalogueCorrectionCommand } from '~/domain/catalogue-correction/command'
import {
  isDescribed,
  isWorthDescribing,
  shelvedNarratorsOf,
  unshelvedNarratorOf,
} from '~/domain/narrator/business-rules'
import { NarratorCommand } from '~/domain/narrator/command'
import { NarratorQuery } from '~/domain/narrator/query'
import type {
  Narrator,
  NarratorCorrection,
  NarratorKey,
  ShelvedNarrator,
} from '~/domain/narrator/types'
import { isImageAt } from '~/domain/scan/published-cover'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { Language } from '~/domain/shared/language'
import { pageAfter } from '~/domain/shared/page'
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
  /** One page of the Library's narrators list, ordered as the authors' is:
   *  the loved ones first, by name, or the one shelved last first. Which
   *  narrators a page holds depends on the books and the opinions alone; only
   *  the page's own entries are read, in one getAll, for their faces. */
  export const followedPage = async (
    userId: UserId,
    page: { limit: number; after?: string },
    order: AuthorOrder = 'loved',
  ): Promise<{ items: FollowedNarrator[]; hasMore: boolean; endCursor: string | null }> => {
    const [books, opinions, hearted] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
      NarratorQuery.favoriteKeys(userId),
    ])
    const shelved = shelvedNarratorsOf(books, opinions)
    const ranked = match(order)
      .with('name', () => inNameOrder(shelved))
      .with('recent', () => inActivityOrder(shelved))
      .with('loved', () => heartedFirst(inAuthorOrder(shelved), hearted))
      .exhaustive()
    const { items, ...rest } = pageAfter(ranked, page, (narrator) => narrator.key)
    return { items: await withFaces(items, hearted), ...rest }
  }

  /** The narrators of the recordings `keep` keeps, the one shelved last
   *  first, as many as `limit`, with their faces: the Library tab's rail of
   *  narrators, under its authors. Only the entries of those drawn are read,
   *  in one getAll; nothing is asked of the model or of Wikipedia. */
  export const recent = async (
    userId: UserId,
    keep: (book: Book) => boolean,
    limit: number,
  ): Promise<FollowedNarrator[]> => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    const narrators = inActivityOrder(shelvedNarratorsOf(books.filter(keep), opinions)).slice(
      0,
      limit,
    )
    return withFaces(narrators, await NarratorQuery.favoriteKeys(userId))
  }

  /** These narrators with their faces, the entries read in one getAll: only
   *  the rows about to be drawn should be passed. */
  const withFaces = async (
    narrators: readonly ShelvedNarrator<Book>[],
    hearted: ReadonlySet<NarratorKey>,
  ): Promise<FollowedNarrator[]> => {
    const entries = await NarratorQuery.byKeys(narrators.map((narrator) => narrator.key))
    const portraits = new Map(entries.map((entry) => [entry.key, entry.portraitUrl]))
    return narrators.map((narrator) => ({
      ...narrator,
      portraitUrl: portraits.get(narrator.key),
      favorite: hearted.has(narrator.key),
    }))
  }

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
      catalogue: isDescribed(entry) ? entry : null,
      awaitingCatalogue,
      sagas: inPageOrder(sagas),
      books: standaloneBooksOf(shelved.books),
    }
  }

  /** Correct what the world knows of a narrator, for every reader: the
   *  fields the correction names, kept from then on over anything the model
   *  or Wikipedia says. Who changed what is recorded apart. A portrait's
   *  address must serve an image.
   *
   *  Answers the narrator's page as it now reads, without describing them;
   *  null when the reader holds no recording of theirs, `not-an-image` for a
   *  portrait that is none. */
  export const correct = async (
    userId: UserId,
    key: NarratorKey,
    language: Language,
    correction: NarratorCorrection,
  ): Promise<NarratorPage | null | 'not-an-image'> => {
    const shelved = await shelvedNarrator(userId, key)
    if (!shelved) return null
    if (correction.portraitUrl && !(await isImageAt(CoverUrl(correction.portraitUrl))))
      return 'not-an-image'
    const known = await NarratorQuery.byKey(key)
    await NarratorCommand.correct(known, key, shelved.name, correction)
    await CatalogueCorrectionCommand.record(
      userId,
      'narrator',
      key,
      (Object.keys(correction) as (keyof NarratorCorrection)[]).map((field) => ({
        field,
        before: known?.[field] ?? null,
        after: correction[field] ?? null,
      })),
    )
    return page(userId, key, language, undefined, { waitForCatalogue: false })
  }

  /** The faces the reader may give a narrator: the one drawn now first, then
   *  what Wikipedia shows for their name. Free. Null when the reader holds no
   *  recording of theirs. */
  export const portraitChoices = async (
    userId: UserId,
    key: NarratorKey,
  ): Promise<PortraitChoice[] | null> => {
    const shelved = await shelvedNarrator(userId, key)
    if (!shelved) return null
    const known = await NarratorQuery.byKey(key)
    const found = await NarratorQuery.portraitFor(known?.name ?? shelved.name)
    const current = known?.portraitUrl
    const choices: PortraitChoice[] = []
    if (current)
      choices.push({
        source: found === current ? 'wikipedia' : 'web',
        url: current,
        isCurrent: true,
      })
    if (found && found !== current)
      choices.push({ source: 'wikipedia', url: found, isCurrent: false })
    return choices
  }

  /** The narrator among the reader's recordings, null when they hold none. */
  const shelvedNarrator = async (userId: UserId, key: NarratorKey) => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    return shelvedNarratorsOf(books, opinions).find((narrator) => narrator.key === key) ?? null
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
