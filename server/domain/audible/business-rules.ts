import type { AudibleItem, LastPosition } from 'audible-api-ts'
import { genreFrom, subgenresFrom } from '~/domain/audible/genre-mapping'
import { AudibleAsin } from '~/domain/audible/primitives'
import type {
  AudibleAsin as AudibleAsinValue,
  AudibleConnection,
  ImportableBook,
} from '~/domain/audible/types'
import { shelfKeyOf, shelfKeysOf } from '~/domain/book/business-rules'
import type { NewBook } from '~/domain/book/command'
import {
  BookLanguageValue,
  CoverUrl,
  Isbn13,
  ListeningMinutes,
  MAX_NARRATORS,
  NarratorName,
  Publisher,
  Synopsis,
} from '~/domain/book/primitives'
import type {
  Book,
  BookId,
  ListeningMinutes as ListeningMinutesValue,
  ReadingStatus,
} from '~/domain/book/types'
import { SeriesName, seriesKeyOf, VolumeNumber } from '~/domain/series/primitives'
import type { VolumeNumber as VolumeNumberValue } from '~/domain/series/types'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { AuthorName as AuthorNameValue, UserId } from '~/domain/shared/types'
import { isPresent, optionally } from '~/utils/input'

/** What one Audible title becomes in a Shiori library.
 *
 *  Every field goes through its brand's constructor and is dropped when it does
 *  not validate, exactly as a scan result is: this is somebody else's API, and
 *  one malformed ISBN must not cost the reader the rest of the record.
 *
 *  Returns undefined for a row with no usable title or no ASIN — there is nothing
 *  to catalogue and nothing to tick in the picker. */
export const importableFrom = (
  item: AudibleItem,
  ownedKeys: ReadonlySet<string>,
  heard?: LastPosition,
): ImportableBook | undefined => {
  const asin = optionally(item.asin, AudibleAsin)
  const title = optionally(item.title, BookTitle)
  if (!asin || !title) return undefined

  const authors = authorsOf(item)
  const status = statusOf(item, heard)
  // Audible spells the language out ("french", "english"), and files a handful
  // of titles under a language nobody expected. Unknown ones are dropped: a
  // guess here would split a saga's shelves on a value nothing established.
  const language = optionally(languageCodeOf(item.language), BookLanguageValue)

  return {
    asin,
    title,
    authors,
    narrators: (item.narrators ?? [])
      .map((narrator) => optionally(narrator, NarratorName))
      .filter(isPresent)
      .slice(0, MAX_NARRATORS),
    durationMinutes: optionally(item.durationMinutes, ListeningMinutes),
    publisher: optionally(item.publisher, Publisher),
    synopsis: optionally(plainTextOf(item.summary ?? item.merchandisingSummary), Synopsis),
    // Audible carries the ISBN of the printed edition when it has one at all, so
    // this is the one field that can reach Open Library later.
    isbn13: optionally(item.isbn, Isbn13),
    language,
    coverUrl: optionally(largestCoverOf(item), CoverUrl),
    genre: genreFrom(item),
    subgenres: subgenresFrom(item, language),
    series: seriesMembershipOf(item, authors),
    status,
    // Only a finished book has a finishing date to keep. A part-listened title
    // gets today's start stamp like any book the reader moves to "reading".
    // Audible's own finishing date, else the night the player stopped at the
    // end: a title finished by the three-minute rule has no date of Audible's.
    finishedAt:
      status === 'read' ? (item.listeningStatus?.finishedAt ?? heard?.lastUpdatedAt) : undefined,
    listenedMinutes: listenedMinutesOf(heard),
    addedAt: purchaseDateOf(item),
    alreadyInLibrary: ownedKeys.has(shelfKeyOf(title, authors[0])),
  }
}

/** The record an import writes. `format` is always `audiobook`: that is what the
 *  reader owns, whatever edition the work also exists in.
 *
 *  No `firstPublishedIn`. Audible's release date is the date the recording came
 *  out, and the field means the year the work first appeared — filling one with
 *  the other would date "Dune" to 2018 and say so on the book screen.
 *
 *  The genre is Audible's own shelf, read off the category ladder by id rather
 *  than by name — see `genre-mapping.ts` for why that distinction is the whole
 *  trick. It is absent for a marketplace whose ids are unknown, and the reader
 *  then picks one on the book screen as they do for a book typed by hand.
 *
 *  Subgenres carry what no genre could hold: a shelf that names an audience or a
 *  theme rather than a kind of story. They come alongside the genre rather than
 *  instead of it — a young-adult thriller is a thriller filed under "Young adult".
 *
 *  The running time is kept, though: it is the only source there is for it, and
 *  the dashboard counts hours listened the way it counts pages read. So are the
 *  narrators, for the same reason — nothing else in Shiori ever learns them. */
export const bookFrom = (importable: ImportableBook): NewBook => ({
  title: importable.title,
  authors: importable.authors,
  format: 'audiobook',
  publisher: importable.publisher,
  synopsis: importable.synopsis,
  isbn13: importable.isbn13,
  publishedCoverUrl: importable.coverUrl,
  genre: importable.genre,
  subgenres: importable.subgenres,
  series: importable.series,
  status: importable.status,
  language: importable.language,
  finishedAt: importable.finishedAt,
  addedAt: importable.addedAt,
  durationMinutes: importable.durationMinutes,
  listenedMinutes: importable.listenedMinutes,
  narrators: importable.narrators,
  audibleAsin: importable.asin,
})

/** The roles Audible tags inside a contributor's own name, as they reach us.
 *
 *  English on most marketplaces, the local language on some — which is why this
 *  is a short list and not one suffix. */
const TRANSLATOR_ROLE =
  /\s*[-\u2013\u2014]\s*(translator|traducteur|traduction|\u00fcbersetzer|traduttore|traductor|tradutor)\.?\s*$/i

/** Who actually wrote it.
 *
 *  Audible files every contributor under `authors` and tags the role in the name
 *  itself — "Danusia Stok - translator" — so a translated novel arrives with a
 *  second author who never wrote a word of it, the word "translator" showing on
 *  the book screen. Shiori has nowhere to record a translator, so the credit is
 *  dropped rather than shelved as an author.
 *
 *  When every credit is a translator, the stripped names are kept instead: a
 *  title Audible credits to its translator alone would otherwise lose its author
 *  line and, with it, its place in a saga — `seriesMembershipOf` keys on the
 *  first author, and no author means no key. */
const authorsOf = (item: AudibleItem): AuthorNameValue[] => {
  const credits = (item.authors ?? []).map((author) => ({
    name: author.replace(TRANSLATOR_ROLE, '').trim(),
    translated: TRANSLATOR_ROLE.test(author),
  }))
  const wrote = credits.filter((credit) => !credit.translated)
  return (wrote.length > 0 ? wrote : credits)
    .map((credit) => optionally(credit.name, AuthorName))
    .filter(isPresent)
}

/** How far into a title the player must have stopped for the reader to be in
 *  it. A position of a minute or two is a title opened by curiosity — a sample,
 *  a wrong tap — and filing it as being read would put a dozen such on the
 *  reader's nightstand. Five minutes is past the opening credits of any title. */
const STARTED_AFTER_MS = 5 * 60 * 1000

/** How close to the end the player must have stopped for the title to be
 *  finished. Audible keeps a title "unfinished" when the reader stops during
 *  the closing credits or the publisher's trailer; three minutes from the end
 *  is the end of any story. */
const FINISHED_WITHIN_MS = 3 * 60 * 1000

/** Whether the player stopped close enough to the end to call the title
 *  finished. A title with no running time cannot say. */
const heardToTheEnd = (item: AudibleItem, heard?: LastPosition): boolean =>
  heard !== undefined &&
  item.durationMinutes > 0 &&
  heard.positionMs >= item.durationMinutes * 60 * 1000 - FINISHED_WITHIN_MS

/** Where the player last stopped, in whole minutes. Undefined for a title the
 *  player never opened, or left before its first minute. */
const listenedMinutesOf = (heard?: LastPosition) =>
  heard ? optionally(Math.floor(heard.positionMs / 60_000), ListeningMinutes) : undefined

/** Where the reader stands in a title, as Audible knows it. Anything finished
 *  is "read", anything started is "reading", and an untouched purchase lands
 *  on the pile — which is exactly what an unopened Audible title is.
 *
 *  Started is read off where the player last stopped, when the caller asked
 *  for it: the library's own percentage is stale, reporting 0 on a title two
 *  hours in, and is kept only as a second opinion for a title the player never
 *  saved a position for. */
export const statusOf = (item: AudibleItem, heard?: LastPosition): ReadingStatus => {
  const listening = item.listeningStatus
  if (listening?.isFinished || heardToTheEnd(item, heard)) return 'read'
  if ((heard?.positionMs ?? 0) >= STARTED_AFTER_MS) return 'reading'
  return (listening?.percentComplete ?? 0) > 0 ? 'reading' : 'to-read'
}

/** The positions the player saved, by title, for the rules that read them. */
export const heardByAsin = (
  positions: readonly LastPosition[],
): ReadonlyMap<string, LastPosition> =>
  new Map(positions.map((position) => [position.asin, position]))

/** The saga the title belongs to, keyed the same way a scan keys it, so an
 *  imported volume joins the very catalogue a scanned one built.
 *
 *  Without an author there is no stable key, so the membership is dropped rather
 *  than given an id nothing else shares — the same rule the scan applies. */
const seriesMembershipOf = (
  item: AudibleItem,
  authors: readonly AuthorNameValue[],
): ImportableBook['series'] => {
  const name = optionally(item.series?.name, SeriesName)
  if (!name || authors.length === 0) return undefined
  return {
    id: seriesKeyOf(name, authors[0]),
    name,
    volume: volumeOf(item.series?.position),
    kind: 'main',
  }
}

/** The volume an Audible position names on the saga's spine.
 *
 *  Audible numbers a side story between two volumes "4.5", and the parts of a
 *  novel too long for one recording "1.1" and "1.2". A part is the volume it was
 *  cut from — the printed book is one volume — while a side story has no rank
 *  on the spine and keeps its place in the saga without one. */
const volumeOf = (position: number | undefined) => {
  if (position === undefined || position % 1 === 0.5) return undefined
  return optionally(Math.floor(position), VolumeNumber)
}

/** The volume numbers to give books imported before split novels were numbered.
 *
 *  Such a book joined its saga without a rank, and the saga drew a placeholder
 *  for the very volume it is. Only a book still filed under the saga Audible
 *  names moves: one the reader filed elsewhere by hand is theirs, and one that
 *  already has a number keeps it. */
export const seriesVolumesFor = (
  books: readonly Book[],
  items: readonly AudibleItem[],
): { bookId: BookId; volume: VolumeNumberValue }[] => {
  const byAsin = new Map(items.map((item) => [item.asin, item]))

  return books.flatMap((book) => {
    if (!book.audibleAsin || !book.series || book.series.volume !== undefined) return []
    const item = byAsin.get(book.audibleAsin)
    const membership = item && seriesMembershipOf(item, authorsOf(item))
    if (!membership?.volume || membership.id !== book.series.id) return []
    return [{ bookId: book.id, volume: membership.volume }]
  })
}

/** Audible names a language rather than coding it, and does so in English on
 *  every marketplace. Anything unrecognized comes back undefined and the book
 *  simply keeps no language, which is what an unknown language is. */
const AUDIBLE_LANGUAGES: Record<string, string> = {
  french: 'fr',
  english: 'en',
  spanish: 'es',
  german: 'de',
  italian: 'it',
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
  mandarin_chinese: 'zh',
  korean: 'ko',
}

const languageCodeOf = (language: string | undefined): string | undefined =>
  language ? AUDIBLE_LANGUAGES[language.trim().toLowerCase().replace(/\s+/g, '_')] : undefined

/** The biggest cover Audible offers, which is what a Retina book screen wants.
 *  `productImages` is keyed by pixel width as a string. */
const largestCoverOf = (item: AudibleItem): string | undefined => {
  const bySize = Object.entries(item.productImages ?? {})
    .map(([size, url]) => [Number(size), url] as const)
    .filter(([size, url]) => Number.isFinite(size) && typeof url === 'string')
    .sort(([left], [right]) => right - left)
  return bySize[0]?.[1] ?? item.coverUrl
}

/** Audible's summaries arrive as HTML. Stored as written they would render as
 *  `<p>` on the book screen, so the markup is taken out here rather than in every
 *  view that draws a synopsis. */
export const plainTextOf = (html: string | undefined): string | undefined => {
  if (!html) return undefined
  return (
    html
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n\n')
      .replace(/<[^>]*>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;|&apos;/g, "'")
      .replace(/\n{3,}/g, '\n\n')
      .trim()
      // Audible summaries run long; a synopsis is capped at 4000 characters, and a
      // truncated one beats losing it to a failed constructor.
      .slice(0, 4000)
      .trim()
  )
}

// What counts as "the reader already has this one" is the book domain's shelf
// key, shared with the Kindle import and the friends' shelves.
export { shelfKeyOf, shelfKeysOf }

/** The Audible title each catalogued book stands for, for the books that have no
 *  ASIN on them yet.
 *
 *  Imports made before the link was kept would otherwise sit outside the sync
 *  forever, so they are matched once on the shelf key and pinned for good. Only
 *  audiobooks are eligible: a printed edition sharing a title with a recording
 *  must never inherit its ASIN, because that is what would let Audible start
 *  moving a book the reader catalogued from a photo.
 *
 *  An ASIN already worn by another book is not handed out twice — two records of
 *  the same story would otherwise fight over one title's listening status. */
export const audibleLinksFor = (
  books: readonly Book[],
  items: readonly AudibleItem[],
): { bookId: BookId; audibleAsin: AudibleAsinValue }[] => {
  const byShelfKey = new Map<string, AudibleAsinValue>()
  for (const item of items) {
    const asin = optionally(item.asin, AudibleAsin)
    if (asin && item.title) byShelfKey.set(shelfKeyOf(item.title, item.authors?.[0]), asin)
  }
  const taken = new Set<string>(
    books.flatMap((book) => (book.audibleAsin ? [book.audibleAsin] : [])),
  )

  return books.flatMap((book) => {
    if (book.audibleAsin || book.format !== 'audiobook') return []
    const audibleAsin = byShelfKey.get(shelfKeyOf(book.title, book.authors[0]))
    if (!audibleAsin || taken.has(audibleAsin)) return []
    taken.add(audibleAsin)
    return [{ bookId: book.id, audibleAsin }]
  })
}

/** The status moves that follow the listening, for books linked to a title the
 *  library still holds.
 *
 *  Audible is authoritative here, in both directions: a title it reports as
 *  finished marks the book read, and one it reports as untouched sends it back to
 *  the pile. A book whose status already agrees produces nothing, so a night that
 *  changed nothing writes nothing.
 *
 *  `at` is Audible's own finishing date for a finish, and for a start the day
 *  the player last saved a position: the sync learns of a start after the fact,
 *  and that is the closest date it has, never later than tonight. Without either
 *  the caller stamps the moment of the sync, which is the best it can honestly
 *  say. */
export const listeningChangesFor = (
  books: readonly Book[],
  items: readonly AudibleItem[],
  positions: readonly LastPosition[] = [],
): { bookId: BookId; status: ReadingStatus; at?: Date }[] => {
  const byAsin = new Map(items.map((item) => [item.asin, item]))
  const heard = heardByAsin(positions)

  return books.flatMap((book) => {
    if (!book.audibleAsin) return []
    const item = byAsin.get(book.audibleAsin)
    if (!item) return []
    const position = heard.get(book.audibleAsin)
    const status = statusOf(item, position)
    if (status === book.status) return []
    return [
      {
        bookId: book.id,
        status,
        at:
          status === 'read'
            ? (item.listeningStatus?.finishedAt ?? position?.lastUpdatedAt)
            : status === 'reading'
              ? position?.lastUpdatedAt
              : undefined,
      },
    ]
  })
}

/** Where the player got to in each linked book, for those it moved since the
 *  last pass. A night the player did not move writes nothing. */
export const listenedMinutesFor = (
  books: readonly Book[],
  positions: readonly LastPosition[],
): { bookId: BookId; listenedMinutes: ListeningMinutesValue }[] => {
  const heard = heardByAsin(positions)
  return books.flatMap((book) => {
    if (!book.audibleAsin) return []
    const listenedMinutes = listenedMinutesOf(heard.get(book.audibleAsin))
    if (listenedMinutes === undefined || listenedMinutes === book.listenedMinutes) return []
    return [{ bookId: book.id, listenedMinutes }]
  })
}

/** When a title entered the reader's Audible library: the day Amazon added it,
 *  else the day it was bought. Undefined for a title it dates neither way. */
const purchaseDateOf = (item: AudibleItem): Date | undefined => item.dateAdded ?? item.purchaseDate

/** The dates to move on books imported before the purchase date was kept.
 *
 *  Such a book carries import night as its addition date, and the library is
 *  cut into months on that date — a 2019 purchase filed under this month. The
 *  move is one-way and one-shot: only a book dated after Amazon's date moves,
 *  and once moved the dates agree.
 *
 *  The import stamped every date it did not know with one instant, so a start
 *  or a status stamp equal to the addition date is that same guess and moves
 *  with it. One that differs was set by the reader afterwards and is theirs. */
export const purchaseDatesFor = (
  books: readonly Book[],
  items: readonly AudibleItem[],
): { bookId: BookId; addedAt: Date; startedAt?: Date; statusChangedAt?: Date }[] => {
  const byAsin = new Map(items.map((item) => [item.asin, item]))

  return books.flatMap((book) => {
    if (!book.audibleAsin) return []
    const item = byAsin.get(book.audibleAsin)
    const addedAt = item && purchaseDateOf(item)
    if (!addedAt || addedAt.getTime() >= book.addedAt.getTime()) return []
    const stamped = (date: Date | undefined) => date?.getTime() === book.addedAt.getTime()
    return [
      {
        bookId: book.id,
        addedAt,
        ...(stamped(book.startedAt) ? { startedAt: addedAt } : {}),
        ...(stamped(book.statusChangedAt) ? { statusChangedAt: addedAt } : {}),
      },
    ]
  })
}

/** The titles bought since the reader last looked.
 *
 *  The cutoff is what keeps the sync from undoing a choice: everything on offer
 *  when the reader last picked was already declined by not being ticked, and
 *  importing it tonight would overrule them. A title Amazon dates neither by
 *  purchase nor by addition is left out for the same reason — it cannot be shown
 *  to be new.
 *
 *  Without a cutoff the whole library is new, which is the case of a reader who
 *  connected their account and never imported. */
export const boughtSince = (
  items: readonly AudibleItem[],
  since: Date | undefined,
): AudibleItem[] => {
  if (!since) return [...items]
  return items.filter((item) => {
    const at = purchaseDateOf(item)
    return at !== undefined && at.getTime() > since.getTime()
  })
}

/** The readers a nightly run should pass over, staleest first.
 *
 *  A half-finished sign-in is not an account and has nothing to sync. The order
 *  is what makes the job's time budget safe to hit: whoever is cut off tonight
 *  sorts to the front tomorrow, so no reader can be starved by a library that
 *  always runs long. A reader never synced has no date and goes first of all. */
export const readersDueForSync = (connections: readonly AudibleConnection[]): UserId[] =>
  connections
    .filter((connection) => connection.account && connection.account.autoSync !== false)
    .sort(
      (left, right) =>
        (left.account?.lastImportedAt?.getTime() ?? 0) -
        (right.account?.lastImportedAt?.getTime() ?? 0),
    )
    .map((connection) => connection.userId)
