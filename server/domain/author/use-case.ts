import { match } from 'ts-pattern'
import { AdminCommand } from '~/domain/admin/command'
import {
  heartedFirst,
  inActivityOrder,
  inAuthorOrder,
  inNameOrder,
  inPageOrder,
  isPortraitWorthSeeking,
  mainLanguageOf,
  matchingAuthorFilter,
  shelvedAuthorsOf,
  standaloneBooksOf,
  unshelvedAuthorOf,
  worksNotHeldOf,
} from '~/domain/author/business-rules'
import { AuthorCommand } from '~/domain/author/command'
import { AuthorQuery } from '~/domain/author/query'
import type {
  Author,
  AuthorCorrection,
  AuthorKey,
  AuthorWork,
  PortraitChoice,
  PortraitUrl,
  ShelvedAuthor,
} from '~/domain/author/types'
import { CoverUrl } from '~/domain/book/primitives'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { CatalogueCorrectionCommand } from '~/domain/catalogue-correction/command'
import { isImageAt } from '~/domain/scan/published-cover'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { Language } from '~/domain/shared/language'
import { pageAfter } from '~/domain/shared/page'
import type { AuthorName, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('author')

/** How the Authors tab lists its rows: the loved ones first, by name, or the
 *  ones read most recently first. */
export type AuthorOrder = 'loved' | 'name' | 'recent'

/** An author of the Authors tab: what the library says, and the portrait once
 *  somebody has opened their page. */
/** `favorite` is the reader's own heart on the author, apart from the hearts
 *  their books and sagas carry. */
export type FollowedAuthor = ShelvedAuthor<Book> & { portraitUrl?: PortraitUrl; favorite?: boolean }

/** Everything an author's page draws, in one answer: what the world knows of
 *  them, and what the reader holds and thinks of their work. */
export type AuthorPage = {
  author: FollowedAuthor
  /** Null when the model could not describe the author: the page still shows
   *  the reader's own books, and only a refresh asks again. */
  catalogue: Author | null
  /** Nobody has described the author yet, and the page would not wait for the
   *  model: it draws the reader's books, and asks again for the catalogue. */
  awaitingCatalogue: boolean
  /** The reader's sagas of this author, read into first. */
  sagas: FollowedSeries[]
  /** The reader's books of this author outside any saga, read first. */
  books: Book[]
  /** The catalogue's books outside any saga the reader does not hold. */
  booksNotHeld: AuthorWork[]
}

export namespace AuthorUseCase {
  /** One page of the Authors tab, the authors the reader loves first — or in
   *  alphabetical order, as a contact list, when `order` is `name`, or the most
   *  recently shelved first when it is `recent` — narrowed
   *  to those with a heart when `favorite` is set.
   *
   *  Which authors a page holds depends on the books and the opinions alone —
   *  one scan each, shared with the rest of the request. Only the page's own
   *  author catalogues are read, in one getAll, for their portraits. */
  export const followedPage = async (
    userId: UserId,
    page: { limit: number; after?: string; offset?: number },
    filter: { favorite?: boolean },
    order: AuthorOrder = 'loved',
  ): Promise<{ items: FollowedAuthor[]; hasMore: boolean; endCursor: string | null }> => {
    const [shelved, hearted] = await Promise.all([
      shelvedAuthors(userId),
      AuthorQuery.favoriteKeys(userId),
    ])
    const matching = matchingAuthorFilter(shelved, filter, hearted)
    const ranked = match(order)
      .with('name', () => inNameOrder(matching))
      .with('recent', () => inActivityOrder(matching))
      .with('loved', () => heartedFirst(inAuthorOrder(matching), hearted))
      .exhaustive()
    const { items, ...rest } = pageAfter(ranked, page, (author) => author.key)
    return { items: await withPortraits(items, userId), ...rest }
  }

  /** The authors of the books `keep` keeps, the one shelved last first, as
   *  many as `limit`, with their portraits: the Library tab's rail of authors,
   *  narrowed to its format or genre. The catalogues of those alone are read. */
  export const recent = async (
    userId: UserId,
    keep: (book: Book) => boolean,
    limit: number,
  ): Promise<FollowedAuthor[]> => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    const authors = inActivityOrder(shelvedAuthorsOf(books.filter(keep), opinions))
    return withPortraits(authors.slice(0, limit), userId)
  }

  /** An author's page, their catalogue built the first time anybody opens it:
   *  one grounded call and a Wikipedia lookup, paid once for everyone, from the
   *  name the reader's books give — and titled in the language most of those
   *  books are in, as a saga's catalogue is titled for the edition held.
   *
   *  An author the reader holds no book of is built from the name `offered`,
   *  as Découvrir offers one a friend loves: everything of theirs is then
   *  something to add. Null without it, or when it names somebody else. */
  export const page = async (
    userId: UserId,
    key: AuthorKey,
    language: Language,
    offered?: AuthorName,
    { waitForCatalogue = true }: { waitForCatalogue?: boolean } = {},
  ): Promise<AuthorPage | null> => {
    const shelved =
      (await shelvedAuthors(userId)).find((author) => author.key === key) ??
      (offered ? unshelvedAuthorOf<Book>(key, offered, new Date()) : null)
    if (!shelved) return null
    const [found, sagas] = await Promise.all([
      waitForCatalogue ? catalogueOf(shelved, language) : storedCatalogueOf(shelved),
      SeriesUseCase.followedAmong(userId, new Set(shelved.seriesIds)),
    ])
    const awaitingCatalogue = found === 'unasked'
    const catalogue = found === 'unasked' ? null : found
    const hearted = await AuthorQuery.favoriteKeys(userId)
    return {
      author: { ...shelved, portraitUrl: catalogue?.portraitUrl, favorite: hearted.has(key) },
      catalogue,
      awaitingCatalogue,
      sagas: inPageOrder(sagas),
      books: standaloneBooksOf(shelved.books),
      booksNotHeld: catalogue ? worksNotHeldOf(catalogue, shelved.books) : [],
    }
  }

  /** Every author the reader holds a book of, with what they made of them:
   *  what Découvrir watches. The books and the opinions, one scan each. */
  export const shelvedAuthors = async (userId: UserId): Promise<ShelvedAuthor<Book>[]> => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    return shelvedAuthorsOf(books, opinions)
  }

  /** These authors with their portraits, the catalogues read in one getAll:
   *  only the rows about to be drawn should be passed. */
  export const withPortraits = async (
    authors: readonly ShelvedAuthor<Book>[],
    userId?: UserId,
  ): Promise<FollowedAuthor[]> => {
    const [catalogues, hearted] = await Promise.all([
      AuthorQuery.byKeys(authors.map((author) => author.key)),
      userId ? AuthorQuery.favoriteKeys(userId) : new Set<AuthorKey>(),
    ])
    const portraits = new Map(catalogues.map((catalogue) => [catalogue.key, catalogue.portraitUrl]))
    return authors.map((author) => ({
      ...author,
      portraitUrl: portraits.get(author.key),
      favorite: hearted.has(author.key),
    }))
  }

  /** Correct what the world knows of an author, where the model or the
   *  portrait lookups were wrong or found nothing: in the shared catalogue, for
   *  every reader, kept from every later call. Every change is logged under the
   *  reader's name, apart from the catalogue. Free: nothing is asked of the
   *  model.
   *
   *  A portrait's address must serve an image: a pasted link to a page would
   *  leave every reader with the initials.
   *
   *  Answers the author's page as it now reads, without building a missing
   *  catalogue; null when the reader holds no book of the author,
   *  `not-an-image` for a portrait that is none. */
  export const correct = async (
    userId: UserId,
    key: AuthorKey,
    language: Language,
    correction: AuthorCorrection,
  ): Promise<AuthorPage | null | 'not-an-image'> => {
    const shelved = (await shelvedAuthors(userId)).find((author) => author.key === key)
    if (!shelved) return null
    if (correction.portraitUrl && !(await isImageAt(CoverUrl(correction.portraitUrl))))
      return 'not-an-image'
    const known = await AuthorQuery.byKey(key)
    await AuthorCommand.correct(known, key, shelved.name, correction)
    await CatalogueCorrectionCommand.record(
      userId,
      'author',
      key,
      (Object.keys(correction) as (keyof AuthorCorrection)[]).map((field) => ({
        field,
        before: known?.[field] ?? null,
        after: correction[field] ?? null,
      })),
    )
    return page(userId, key, language, undefined, { waitForCatalogue: false })
  }

  /** The faces the reader may give an author: the one drawn now first, then
   *  what Wikipedia, Wikidata and Open Library find for their name. Free, as a
   *  book's covers are. Null when the reader holds no book of the author. */
  export const portraitChoices = async (
    userId: UserId,
    key: AuthorKey,
  ): Promise<PortraitChoice[] | null> => {
    const shelved = (await shelvedAuthors(userId)).find((author) => author.key === key)
    if (!shelved) return null
    const known = await AuthorQuery.byKey(key)
    const found = await AuthorQuery.portraitsFor(known?.name ?? shelved.name)
    const current = known?.portraitUrl
    const choices = found.map((choice) => ({ ...choice, isCurrent: choice.url === current }))
    return current && !choices.some((choice) => choice.isCurrent)
      ? [{ source: 'web', url: current, isCurrent: true }, ...choices]
      : [...choices.filter((choice) => choice.isCurrent), ...choices.filter((c) => !c.isCurrent)]
  }

  /** The author's catalogue asked of the world again, at the reader's request:
   *  a catalogue the model could not build on the first opening is never asked
   *  for again otherwise, and one built thin can be rebuilt.
   *
   *  Null when the reader holds no book of the author, and when the model
   *  failed or found nothing — the stored catalogue, if any, is then kept. */
  export const recatalogue = async (
    userId: UserId,
    key: AuthorKey,
    language: Language,
  ): Promise<Author | null> => {
    const shelved = (await shelvedAuthors(userId)).find((author) => author.key === key)
    return shelved ? askTheWeb(shelved, language) : null
  }

  /** The stored catalogue, else one built now — unless the model already
   *  failed on this author: every opening would otherwise wait on the same
   *  grounded call. `recatalogue` asks regardless. A stored catalogue with no
   *  portrait asks Wikipedia again, now and then, by the author's name. */
  const catalogueOf = async (
    shelved: ShelvedAuthor<Book>,
    language: Language,
  ): Promise<Author | null> => {
    const known = await AuthorQuery.byKey(shelved.key)
    if (known)
      return isPortraitWorthSeeking(known, new Date()) ? AuthorCommand.seekPortrait(known) : known
    if (await AuthorQuery.lastMiss(shelved.key)) return null
    return askTheWeb(shelved, language)
  }

  /** The stored catalogue, as `catalogueOf` reads it, without asking the
   *  model: `unasked` when building one is what would come next. */
  const storedCatalogueOf = async (
    shelved: ShelvedAuthor<Book>,
  ): Promise<Author | null | 'unasked'> => {
    const known = await AuthorQuery.byKey(shelved.key)
    if (known)
      return isPortraitWorthSeeking(known, new Date()) ? AuthorCommand.seekPortrait(known) : known
    if (await AuthorQuery.lastMiss(shelved.key)) return null
    return 'unasked'
  }

  const askTheWeb = async (
    shelved: ShelvedAuthor<Book>,
    language: Language,
  ): Promise<Author | null> => {
    const { author, usage } = await AuthorCommand.catalogueFromWeb(
      shelved.key,
      shelved.name,
      language,
      mainLanguageOf(shelved.books),
    )
    // Telemetry: the catalogue is already built, so a failed counter write is
    // logged rather than turned into an error the reader has to read.
    if (usage)
      await AdminCommand.recordCatalogueUsage(usage).catch((error) =>
        logger.warn('AI usage not recorded', { error }),
      )
    return author ?? null
  }
}
