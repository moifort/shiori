import { match } from 'ts-pattern'
import { AdminCommand } from '~/domain/admin/command'
import {
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
  AuthorKey,
  AuthorWork,
  PortraitUrl,
  ShelvedAuthor,
} from '~/domain/author/types'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('author')

/** How the Authors tab lists its rows: the loved ones first, by name, or the
 *  ones read most recently first. */
export type AuthorOrder = 'loved' | 'name' | 'recent'

/** An author of the Authors tab: what the library says, and the portrait once
 *  somebody has opened their page. */
export type FollowedAuthor = ShelvedAuthor<Book> & { portraitUrl?: PortraitUrl }

/** Everything an author's page draws, in one answer: what the world knows of
 *  them, and what the reader holds and thinks of their work. */
export type AuthorPage = {
  author: FollowedAuthor
  /** Null when the model could not describe the author: the page still shows
   *  the reader's own books, and only a refresh asks again. */
  catalogue: Author | null
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
    page: { limit: number; offset: number },
    filter: { favorite?: boolean },
    order: AuthorOrder = 'loved',
  ): Promise<{ items: FollowedAuthor[]; hasMore: boolean }> => {
    const matching = matchingAuthorFilter(await shelvedAuthors(userId), filter)
    const ranked = match(order)
      .with('name', () => inNameOrder(matching))
      .with('recent', () => inActivityOrder(matching))
      .with('loved', () => inAuthorOrder(matching))
      .exhaustive()
    return {
      items: await withPortraits(ranked.slice(page.offset, page.offset + page.limit)),
      hasMore: page.offset + page.limit < ranked.length,
    }
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
  ): Promise<AuthorPage | null> => {
    const shelved =
      (await shelvedAuthors(userId)).find((author) => author.key === key) ??
      (offered ? unshelvedAuthorOf<Book>(key, offered, new Date()) : null)
    if (!shelved) return null
    const [catalogue, sagas] = await Promise.all([
      catalogueOf(shelved, language),
      SeriesUseCase.followedAmong(userId, new Set(shelved.seriesIds)),
    ])
    return {
      author: { ...shelved, portraitUrl: catalogue?.portraitUrl },
      catalogue,
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
  ): Promise<FollowedAuthor[]> => {
    const portraits = new Map(
      (await AuthorQuery.byKeys(authors.map((author) => author.key))).map((catalogue) => [
        catalogue.key,
        catalogue.portraitUrl,
      ]),
    )
    return authors.map((author) => ({ ...author, portraitUrl: portraits.get(author.key) }))
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
