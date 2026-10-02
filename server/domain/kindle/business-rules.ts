import type { KindleTitle } from 'kindle-api-ts'
import { keepsCopyOf, type Shelf, shelfKeyOf } from '~/domain/book/business-rules'
import type { NewBook } from '~/domain/book/command'
import { CoverUrl } from '~/domain/book/primitives'
import type {
  Book,
  BookId,
  BookLanguage,
  CoverUrl as CoverUrlValue,
  ReadingStatus,
  SeriesMembership,
} from '~/domain/book/types'
import type { TitleRead } from '~/domain/kindle/infrastructure/title-reader'
import { KindleAsin } from '~/domain/kindle/primitives'
import type {
  ImportableKindleBook,
  KindleAsin as KindleAsinValue,
  KindleConnection,
  KindleMarketplace,
  ReadKindleTitle,
} from '~/domain/kindle/types'
import { SeriesName, seriesKeyOf, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'
import { isPresent, optionally } from '~/utils/input'
import { slugify } from '~/utils/slug'

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
type Split = { title: string; series?: { name: string; volume?: number } }

export const sagaOf = (rawTitle: string): Split => {
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

/** The language each store sells its own editions in. */
const STORE_LANGUAGES: Record<KindleMarketplace, BookLanguage> = {
  fr: 'fr',
  com: 'en',
  'co.uk': 'en',
  de: 'de',
  it: 'it',
  es: 'es',
  ca: 'en',
  'com.au': 'en',
  in: 'en',
  'co.jp': 'ja',
}

/** The language a store sells in: that of every edition it names no language
 *  of. */
export const storeLanguageOf = (marketplace: KindleMarketplace): BookLanguage =>
  STORE_LANGUAGES[marketplace]

/** The language of the edition, as Amazon names it.
 *
 *  The list carries no language field, but a store names the language of an
 *  edition foreign to it: in the title for some ("(English Edition)" on
 *  amazon.fr), in the sort key for every one ("… french edition"). The title is
 *  read first, the sort key after. An edition named nowhere is in the store's
 *  own language, when the store is known. */
export const editionLanguageOf = (
  title: string,
  sortableTitle: string | undefined,
  store?: BookLanguage,
): BookLanguage | undefined => {
  const named = [
    ...TITLE_LANGUAGE_MENTIONS.map((pattern) => title.match(pattern)?.[1]),
    sortableTitle?.match(SORT_KEY_LANGUAGE)?.[1],
  ]
  return (
    named
      .map((word) => (word ? EDITION_LANGUAGES[word.toLowerCase()] : undefined))
      .find(isPresent) ?? store
  )
}

/** Whether the Amazon title carries this volume number: "T06", "Tome 02",
 *  "#5", "T3.5". Not a digit of another number — 3 is not in "T3.5" nor in
 *  "1984". */
export const carriesVolume = (amazonTitle: string, volume: number): boolean =>
  new RegExp(
    String.raw`(?<![\d.])0*${String(volume).replace('.', String.raw`\.`)}(?![.,]?\d)`,
  ).test(amazonTitle)

/** The model's answer for one title, checked. A volume number is kept only
 *  when the Amazon title carries it: the saga a famous title belongs to is
 *  well known, the order of its volumes far less — on the first library tried,
 *  three volumes of one saga came back numbered wrong. The saga is kept
 *  without its number then. */
export const readTitleFrom = (
  item: KindleTitle,
  answer: TitleRead,
  readAt: Date,
): ReadKindleTitle | undefined => {
  const asin = optionally(item.asin, KindleAsin)
  const title = optionally(answer.title?.trim(), BookTitle)
  if (!asin || !title) return undefined
  const seriesName = answer.seriesName?.trim() || undefined
  const volume =
    seriesName && answer.volumeNumber && carriesVolume(item.title, answer.volumeNumber)
      ? answer.volumeNumber
      : undefined
  return { asin, amazonTitle: item.title, title, seriesName, volume, readAt }
}

/** A title split into the volume's own title and its saga: the model's reading
 *  when there is one for this very title, the patterns otherwise. */
export const splitOf = (item: KindleTitle, reads: ReadonlyMap<string, ReadKindleTitle>): Split => {
  const read = reads.get(item.asin)
  if (!read || read.amazonTitle !== item.title) return sagaOf(item.title)
  return {
    title: read.title,
    series: read.seriesName ? { name: read.seriesName, volume: read.volume } : undefined,
  }
}

const membershipOf = (
  saga: Split['series'],
  author: string | undefined,
): SeriesMembership | undefined => {
  const name = optionally(saga?.name, SeriesName)
  const volume = optionally(saga?.volume, VolumeNumber)
  // Without an author there is no stable key, so the membership is dropped
  // rather than given an id nothing else shares — the rule the scan applies.
  if (!name || !author) return undefined
  return { id: seriesKeyOf(name, author, 'book'), name, volume, kind: 'main' }
}

/** One title of the account as the book it would be catalogued as, or nothing
 *  for a title that is no book or carries no usable title. */
export const importableFrom = (
  item: KindleTitle,
  owned: Shelf,
  reads: ReadonlyMap<string, ReadKindleTitle> = new Map(),
  store?: BookLanguage,
): ImportableKindleBook | undefined => {
  if (!isCataloguable(item)) return undefined
  const asin = optionally(item.asin, KindleAsin)
  const saga = splitOf(item, reads)
  const title = optionally(saga.title, BookTitle)
  if (!asin || !title) return undefined

  const authors = item.authors.map((name) => optionally(name, AuthorName)).filter(isPresent)
  const status: ReadingStatus = item.readStatus === 'READ' ? 'read' : 'to-read'
  const series = membershipOf(saga.series, authors[0])
  const language = editionLanguageOf(item.title, item.sortableTitle, store)
  return {
    asin,
    title,
    authors,
    coverUrl: optionally(item.coverUrl, CoverUrl),
    series,
    language,
    status,
    // Amazon says a book was read, never when: the day it was acquired is the
    // honest lower bound, and import night would rewrite the reading statistics.
    finishedAt: status === 'read' ? item.acquiredAt : undefined,
    addedAt: item.acquiredAt,
    alreadyInLibrary: keepsCopyOf(owned, {
      title,
      author: authors[0],
      volume: series?.volume,
      language,
    }),
  }
}

/** The record an import writes: a book held on a screen, under the cover Amazon
 *  shows for it. Nothing is guessed beyond what the list carries — no summary,
 *  no page count, no genre, and no drawn format: a manga on a Kindle is filed a
 *  book until the reader says otherwise, or scans its paper copy. */
export const bookFrom = (importable: ImportableKindleBook): NewBook => ({
  title: importable.title,
  authors: importable.authors,
  format: 'book',
  media: ['digital'],
  kindleCoverUrl: importable.coverUrl,
  series: importable.series,
  language: importable.language,
  status: importable.status,
  finishedAt: importable.finishedAt,
  addedAt: importable.addedAt,
  kindleAsin: importable.asin,
})

/** A book the sync found on the reader's Kindle, and the Kindle title it is. */
export type KindleLink = { bookId: BookId; kindleAsin: KindleAsinValue; coverUrl?: CoverUrlValue }

/** Books catalogued before they were linked — a paperback scanned, an ebook
 *  from the data export or typed by hand — matched to their Kindle title by
 *  shelf key, once, in the same volume and language wherever both say. A
 *  paperback found on the Kindle is then held both ways: one book, whichever
 *  the reader picks up, and the sync moves its status like any Kindle title's.
 *  Never a recording: Audible's, and another object. An ASIN already taken is
 *  not given twice. */
export const kindleLinksFor = (
  books: readonly Book[],
  titles: readonly KindleTitle[],
  reads: ReadonlyMap<string, ReadKindleTitle> = new Map(),
  store?: BookLanguage,
): KindleLink[] => {
  const taken = new Set<string>(books.flatMap((book) => (book.kindleAsin ? [book.kindleAsin] : [])))
  const byShelfKey = new Map<string, LinkableTitle[]>()
  for (const item of titles.filter(isCataloguable)) {
    const asin = optionally(item.asin, KindleAsin)
    if (!asin || taken.has(asin)) continue
    const split = splitOf(item, reads)
    const key = shelfKeyOf(split.title, item.authors[0])
    byShelfKey.set(key, [
      ...(byShelfKey.get(key) ?? []),
      {
        asin,
        coverUrl: optionally(item.coverUrl, CoverUrl),
        volume: split.series?.volume,
        language: editionLanguageOf(item.title, item.sortableTitle, store),
      },
    ])
  }

  return books.flatMap((book) => {
    if (book.kindleAsin || book.format === 'audiobook') return []
    const match = (byShelfKey.get(shelfKeyOf(book.title, book.authors[0])) ?? []).find(
      (title) =>
        !taken.has(title.asin) &&
        agrees(book.series?.volume, title.volume) &&
        agrees(book.language, title.language),
    )
    if (!match) return []
    taken.add(match.asin)
    return [{ bookId: book.id, kindleAsin: match.asin, coverUrl: match.coverUrl }]
  })
}

/** When paperbacks began to be linked to their Kindle title: the deploy of
 *  that change. A pass before it matched ebooks only, so it settled nothing
 *  about a paperback. */
export const PAPERBACKS_LINKED_SINCE = new Date('2026-10-02T12:42:00.000Z')

/** The titles a pass matches books against, so that a pair compared on an
 *  earlier night is not compared again: it did not match then, and neither
 *  side has changed since. A title acquired since the last pass meets every
 *  book; a read book written since — scanned, typed, corrected — meets every
 *  title of its author not yet linked. Everything else was settled before.
 *  With no previous pass, or none since paperbacks are linked, every title not
 *  yet linked is worth a look. */
export const titlesWorthMatching = (
  books: readonly Book[],
  titles: readonly KindleTitle[],
  fresh: readonly KindleTitle[],
  previousPass: Date | undefined,
): KindleTitle[] => {
  const lastPass =
    previousPass && previousPass.getTime() > PAPERBACKS_LINKED_SINCE.getTime()
      ? previousPass
      : undefined
  const taken = new Set<string>(books.flatMap((book) => (book.kindleAsin ? [book.kindleAsin] : [])))
  const acquired = new Set(fresh.map((title) => title.asin))
  const authors = new Set(
    books
      .filter(
        (book) =>
          book.format !== 'audiobook' &&
          !book.kindleAsin &&
          (!lastPass || (book.updatedAt ?? book.addedAt).getTime() > lastPass.getTime()),
      )
      .map((book) => slugify(book.authors[0] ?? '')),
  )
  return titles.filter(
    (title) =>
      !taken.has(title.asin) &&
      (acquired.has(title.asin) || authors.has(slugify(title.authors[0] ?? ''))),
  )
}

type LinkableTitle = {
  asin: KindleAsinValue
  coverUrl?: CoverUrlValue
  volume?: number
  language?: BookLanguage
}

const agrees = <T>(kept: T | undefined, candidate: T | undefined) =>
  kept === undefined || candidate === undefined || kept === candidate

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
