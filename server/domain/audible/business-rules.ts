import type { AudibleItem } from 'audible-api-ts'
import { genreFrom, subgenresFrom } from '~/domain/audible/genre-mapping'
import { AudibleAsin } from '~/domain/audible/primitives'
import type {
  AudibleAsin as AudibleAsinValue,
  AudibleConnection,
  ImportableBook,
} from '~/domain/audible/types'
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
import type { Book, BookId, ReadingStatus } from '~/domain/book/types'
import { SeriesName, seriesKeyOf, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { AuthorName as AuthorNameValue, UserId } from '~/domain/shared/types'
import { isPresent, optionally } from '~/utils/input'
import { slugify } from '~/utils/slug'

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
): ImportableBook | undefined => {
  const asin = optionally(item.asin, AudibleAsin)
  const title = optionally(item.title, BookTitle)
  if (!asin || !title) return undefined

  const authors = authorsOf(item)
  const status = statusOf(item)
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
    finishedAt: status === 'read' ? item.listeningStatus?.finishedAt : undefined,
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
  durationMinutes: importable.durationMinutes,
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

/** Where the reader stands in a title, as Audible knows it. Anything started is
 *  "reading", anything finished is "read", and an untouched purchase lands on the
 *  pile — which is exactly what an unopened Audible title is. */
export const statusOf = (item: AudibleItem): ReadingStatus => {
  const listening = item.listeningStatus
  if (listening?.isFinished) return 'read'
  return (listening?.percentComplete ?? 0) > 0 ? 'reading' : 'to-read'
}

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
    // Audible numbers half-volumes ("4.5") for side stories; VolumeNumber takes
    // whole numbers only, so those keep their place in the saga without a rank.
    volume: optionally(item.series?.position, VolumeNumber),
    kind: 'main',
  }
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

/** What counts as "the reader already has this one".
 *
 *  Title and first author, folded the way series keys are folded, rather than an
 *  identifier: matching on the text means a title the reader scanned from the
 *  printed edition is recognized too, which the ASIN now kept on imported records
 *  would never have caught.
 *
 *  The two answer different questions and both are needed. The shelf key asks
 *  "does the reader already own this story", loosely and across editions, which
 *  is what a duplicate check wants. The ASIN asks "which record is this exact
 *  Audible title", and only it is precise enough to write a status into. */
export const shelfKeyOf = (title: string, author: string | undefined): string =>
  `${slugify(title)}--${slugify(author ?? '')}`

export const shelfKeysOf = (books: readonly Book[]): Set<string> =>
  new Set(books.map((book) => shelfKeyOf(book.title, book.authors[0])))

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
 *  `at` is Audible's own finishing date when it has one. Without it the caller
 *  stamps the moment of the sync, which is the best it can honestly say. */
export const listeningChangesFor = (
  books: readonly Book[],
  items: readonly AudibleItem[],
): { bookId: BookId; status: ReadingStatus; at?: Date }[] => {
  const byAsin = new Map(items.map((item) => [item.asin, item]))

  return books.flatMap((book) => {
    if (!book.audibleAsin) return []
    const item = byAsin.get(book.audibleAsin)
    if (!item) return []
    const status = statusOf(item)
    if (status === book.status) return []
    return [
      {
        bookId: book.id,
        status,
        at: status === 'read' ? item.listeningStatus?.finishedAt : undefined,
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
    const at = item.purchaseDate ?? item.dateAdded
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
