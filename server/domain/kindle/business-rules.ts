import type { KindleTitle } from 'kindle-api-ts'
import { shelfKeyOf } from '~/domain/book/business-rules'
import type { NewBook } from '~/domain/book/command'
import { CoverUrl } from '~/domain/book/primitives'
import type {
  Book,
  BookId,
  BookLanguage,
  ReadingStatus,
  SeriesMembership,
} from '~/domain/book/types'
import { KindleAsin } from '~/domain/kindle/primitives'
import type {
  ImportableKindleBook,
  KindleAsin as KindleAsinValue,
  KindleConnection,
} from '~/domain/kindle/types'
import { SeriesName, seriesKeyOf, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'
import { isPresent, optionally } from '~/utils/input'

/** How a title came to the account that makes it no book of the reader's: the
 *  free extract of a book, and the dictionaries Amazon files under every Kindle
 *  account — 88 of 165 titles on the first account probed. */
const NOT_A_BOOK_ORIGINS = new Set(['Sample', 'KindleDictionary'])

/** Whether a title of the account is a book the reader could catalogue. Every
 *  other origin counts — bought, borrowed through Prime Reading or Kindle
 *  Unlimited, shared by the household: each is a book somebody reads. */
export const isCataloguable = (title: KindleTitle): boolean =>
  !NOT_A_BOOK_ORIGINS.has(title.originType) && !title.category.endsWith('Sample')

/** What Amazon appends to the title of a translated edition. */
const EDITION_SUFFIX = /\s*\((?:[A-Za-zÀ-ÿ]+ Edition|[EÉ]dition [A-Za-zÀ-ÿ]+)\)\s*$/i

/** The word a saga's volume number follows, in the languages the stores sell. */
const VOLUME_WORD = String.raw`(?:tome|t\.|livre|volume|vol\.|book|band|libro)`
const SEPARATOR = String.raw`\s*[-–—:]\s*`

/** The shapes Amazon gives a saga's volume, most specific first. Each names the
 *  saga, the volume, and — when the title carries one after the volume — the
 *  volume's own title. */
const SAGA_PATTERNS: RegExp[] = [
  // "Powerless (Tome 3) - Fearless"
  new RegExp(
    String.raw`^(?<series>.+?)\s*\(${VOLUME_WORD}\s*(?<volume>\d+)\)${SEPARATOR}(?<title>.+)$`,
    'i',
  ),
  // "Powerless, Tome 3 : Fearless", "Powerless - Tome 3 - Fearless", "Le Sorceleur T.4 : …"
  new RegExp(
    String.raw`^(?<series>.+?)(?:\s*[-–—,:]\s*|\s+)${VOLUME_WORD}\s*(?<volume>\d+)${SEPARATOR}(?<title>.+)$`,
    'i',
  ),
  // "Boys of Tommen #5 : Taming 7"
  new RegExp(String.raw`^(?<series>.+?)\s*#(?<volume>\d+)${SEPARATOR}(?<title>.+)$`, 'i'),
  // "Le Nom du vent (Chronique du tueur de roi, tome 1)", "Fearless (Powerless Book 3)"
  new RegExp(
    String.raw`^(?<title>.+?)\s*\((?<series>[^()]+?)[,\s]\s*${VOLUME_WORD}\s*(?<volume>\d+)\)$`,
    'i',
  ),
  // "Powerless (Tome 3)", "Powerless - Tome 3", "Powerless #3"
  new RegExp(
    String.raw`^(?<series>.+?)\s*(?:\(${VOLUME_WORD}\s*(?<volume>\d+)\)|[-–—,:]\s*${VOLUME_WORD}\s*(?<volume2>\d+)|#(?<volume3>\d+))$`,
    'i',
  ),
]

/** A title read for the saga Amazon put in it.
 *
 *  Amazon has no series field on this list; the saga lives in the title, in a
 *  handful of shapes. The volume's own title, when there is one after the
 *  volume, becomes the book's — what a scan of its cover would call it. A title
 *  no pattern recognizes keeps no saga: a guessed saga would file a book on a
 *  shelf nothing else shares. */
export const sagaOf = (
  rawTitle: string,
): { title: string; series?: { name: string; volume: number } } => {
  const title = rawTitle.replace(EDITION_SUFFIX, '').trim()
  for (const pattern of SAGA_PATTERNS) {
    const groups = title.match(pattern)?.groups
    if (!groups) continue
    const volume = Number(groups.volume ?? groups.volume2 ?? groups.volume3)
    const name = groups.series?.trim()
    if (!name || !Number.isInteger(volume)) continue
    return { title: groups.title?.trim() || title, series: { name, volume } }
  }
  return { title }
}

/** The words Amazon names an edition's language with, in the stores' languages:
 *  "(English Edition)", "(Édition Française)", "Version française", and the
 *  "french edition" its sort key ends on. */
const EDITION_LANGUAGES: Record<string, BookLanguage> = {
  french: 'fr',
  française: 'fr',
  francaise: 'fr',
  english: 'en',
  anglaise: 'en',
  spanish: 'es',
  española: 'es',
  german: 'de',
  deutsche: 'de',
  italian: 'it',
  italiana: 'it',
  portuguese: 'pt',
  dutch: 'nl',
  swedish: 'sv',
  polish: 'pl',
  russian: 'ru',
  ukrainian: 'uk',
  turkish: 'tr',
  arabic: 'ar',
  japanese: 'ja',
  chinese: 'zh',
  korean: 'ko',
}

const TITLE_LANGUAGE_MENTIONS = [
  /\((\p{L}+) Edition\)/iu,
  /[EÉ]dition (\p{L}+)/iu,
  /Version (\p{L}+)/iu,
]
const SORT_KEY_LANGUAGE = /\b(\p{L}+) edition(?:, \p{L}+)?$/u

/** The language of the edition, as Amazon names it.
 *
 *  The list carries no language field, but a store names the language of an
 *  edition foreign to it: in the title for some ("(English Edition)" on
 *  amazon.fr), in the sort key for every one ("… french edition"). The title is
 *  read first, the sort key after. An edition in the store's own language may
 *  be named nowhere, and then keeps none rather than a guess. */
export const editionLanguageOf = (
  title: string,
  sortableTitle: string | undefined,
): BookLanguage | undefined => {
  const named = [
    ...TITLE_LANGUAGE_MENTIONS.map((pattern) => title.match(pattern)?.[1]),
    sortableTitle?.match(SORT_KEY_LANGUAGE)?.[1],
  ]
  return named
    .map((word) => (word ? EDITION_LANGUAGES[word.toLowerCase()] : undefined))
    .find(isPresent)
}

const membershipOf = (
  saga: ReturnType<typeof sagaOf>['series'],
  author: string | undefined,
): SeriesMembership | undefined => {
  const name = optionally(saga?.name, SeriesName)
  const volume = optionally(saga?.volume, VolumeNumber)
  // Without an author there is no stable key, so the membership is dropped
  // rather than given an id nothing else shares — the rule the scan applies.
  if (!name || !author) return undefined
  return { id: seriesKeyOf(name, author, 'ebook'), name, volume, kind: 'main' }
}

/** One title of the account as the book it would be catalogued as, or nothing
 *  for a title that is no book or carries no usable title. */
export const importableFrom = (
  item: KindleTitle,
  ownedKeys: ReadonlySet<string>,
): ImportableKindleBook | undefined => {
  if (!isCataloguable(item)) return undefined
  const asin = optionally(item.asin, KindleAsin)
  const saga = sagaOf(item.title)
  const title = optionally(saga.title, BookTitle)
  if (!asin || !title) return undefined

  const authors = item.authors.map((name) => optionally(name, AuthorName)).filter(isPresent)
  const status: ReadingStatus = item.readStatus === 'READ' ? 'read' : 'to-read'
  return {
    asin,
    title,
    authors,
    coverUrl: optionally(item.coverUrl, CoverUrl),
    series: membershipOf(saga.series, authors[0]),
    language: editionLanguageOf(item.title, item.sortableTitle),
    status,
    // Amazon says a book was read, never when: the day it was acquired is the
    // honest lower bound, and import night would rewrite the reading statistics.
    finishedAt: status === 'read' ? item.acquiredAt : undefined,
    addedAt: item.acquiredAt,
    alreadyInLibrary: ownedKeys.has(shelfKeyOf(title, authors[0])),
  }
}

/** The record an import writes. `format` is `ebook`: that is what the reader
 *  owns, whatever edition the work also exists in. Nothing is guessed beyond
 *  what the list carries — no summary, no page count, no genre. */
export const bookFrom = (importable: ImportableKindleBook): NewBook => ({
  title: importable.title,
  authors: importable.authors,
  format: 'ebook',
  publishedCoverUrl: importable.coverUrl,
  series: importable.series,
  language: importable.language,
  status: importable.status,
  finishedAt: importable.finishedAt,
  addedAt: importable.addedAt,
  kindleAsin: importable.asin,
})

/** Ebooks catalogued before they were linked — from the data export, by hand,
 *  by a scan — matched to their Kindle title by shelf key, once. Only an ebook:
 *  a printed copy or a recording of the same story is another object, and the
 *  Kindle sync must never write into it. An ASIN already taken is not given
 *  twice. */
export const kindleLinksFor = (
  books: readonly Book[],
  titles: readonly KindleTitle[],
): { bookId: BookId; kindleAsin: KindleAsinValue }[] => {
  const byShelfKey = new Map<string, KindleAsinValue>()
  for (const item of titles.filter(isCataloguable)) {
    const asin = optionally(item.asin, KindleAsin)
    if (asin) byShelfKey.set(shelfKeyOf(sagaOf(item.title).title, item.authors[0]), asin)
  }
  const taken = new Set<string>(books.flatMap((book) => (book.kindleAsin ? [book.kindleAsin] : [])))

  return books.flatMap((book) => {
    if (book.kindleAsin || book.format !== 'ebook') return []
    const kindleAsin = byShelfKey.get(shelfKeyOf(book.title, book.authors[0]))
    if (!kindleAsin || taken.has(kindleAsin)) return []
    taken.add(kindleAsin)
    return [{ bookId: book.id, kindleAsin }]
  })
}

/** The titles Amazon reports read, as the set the next pass reads news against. */
export const readAsinsOf = (titles: readonly KindleTitle[]): KindleAsinValue[] =>
  titles
    .filter((title) => title.readStatus === 'READ')
    .map((title) => optionally(title.asin, KindleAsin))
    .filter(isPresent)

/** The books to move to read: those whose Kindle title Amazon newly reports read.
 *
 *  `READ` never goes away on Amazon, so it is news only once — a title already in
 *  `previouslyRead` moves nothing, and a reader who starts a book again is not
 *  put back on "read" every night. Nothing ever moves the other way: `UNKNOWN`
 *  does not mean unread.
 *
 *  The first pass has no previous set. It moves only books still on the pile or
 *  being read: one the reader dropped, they dropped. */
export const readingChangesFor = (
  books: readonly Book[],
  titles: readonly KindleTitle[],
  previouslyRead: readonly KindleAsinValue[] | undefined,
): BookId[] => {
  const read = new Set<string>(readAsinsOf(titles))
  const known = new Set<string>(previouslyRead ?? [])
  return books
    .filter((book) => book.kindleAsin && read.has(book.kindleAsin) && !known.has(book.kindleAsin))
    .filter((book) =>
      previouslyRead
        ? book.status !== 'read'
        : book.status === 'to-read' || book.status === 'reading',
    )
    .map((book) => book.id)
}

/** The titles acquired since the cutoff — all of them on a first pass, which has
 *  none. A title with no acquisition date is only new on that first pass: with
 *  no date there is no telling it came since. */
export const acquiredSince = (
  titles: readonly KindleTitle[],
  cutoff: Date | undefined,
): KindleTitle[] =>
  cutoff
    ? titles.filter((title) => title.acquiredAt && title.acquiredAt.getTime() > cutoff.getTime())
    : [...titles]

/** Who the nightly job passes over, the reader least recently synced first.
 *  Readers who turned the sync off are left out. */
export const readersDueForSync = (connections: readonly KindleConnection[]): UserId[] =>
  connections
    .filter((connection) => connection.account && connection.account.autoSync !== false)
    .sort(
      (left, right) =>
        (left.account?.lastImportedAt?.getTime() ?? 0) -
        (right.account?.lastImportedAt?.getTime() ?? 0),
    )
    .map((connection) => connection.userId)
