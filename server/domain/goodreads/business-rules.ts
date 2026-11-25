import { sameAuthor, shelfKeyOf } from '~/domain/book/business-rules'
import type { NewBook } from '~/domain/book/command'
import {
  Isbn13,
  PageCount,
  Publisher,
  ReadingNote,
  StarRating,
  Year,
} from '~/domain/book/primitives'
import type { Book, BookFormat, BookLanguage, BookMedium, CoverUrl } from '~/domain/book/types'
import type {
  GoodreadsChoices,
  GoodreadsPreview,
  GoodreadsPreviewRow,
  GoodreadsRow,
  GoodreadsShelf,
  UnreadableGoodreadsExport,
} from '~/domain/goodreads/types'
import { SeriesName, seriesKeyOf, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { AuthorName as AuthorNameType } from '~/domain/shared/types'
import { csvRowsOf, delimiterOf } from '~/utils/csv'
import { isPresent, optionally } from '~/utils/input'
import { slugify } from '~/utils/slug'

/** The headings every Goodreads library export opens with, checked before any
 *  row is read: a reader handed the wrong file deserves to be told so rather
 *  than shown an empty library. Columns are found by name, never by position:
 *  Goodreads dropped eight of them in 2022 and may move the rest. */
const REQUIRED = ['Book Id', 'Title', 'Author', 'Exclusive Shelf'] as const

/** A custom shelf saying the reader gave the book up. */
const DROPPED_SHELF = /^(dnf|did-?not-?finish|abandon(ed|né|ne)?s?|dropped|gave-?up)$/i

/** "The Way of Kings (The Stormlight Archive, #1)": the saga and its number in
 *  parentheses at the end, the way Goodreads appends them to every volume. A
 *  number that is not a whole one ("#1.5", a novella between two volumes)
 *  keeps the saga and drops the number. */
const SERIES_SUFFIX = /\s*\(([^()]+?),?\s+#\s*([\d.]+)(?:[-–]\d+)?\)\s*$/

export const seriesIn = (
  raw: string,
): { title: string; series?: { name: string; volume?: number } } => {
  const match = raw.match(SERIES_SUFFIX)
  if (!match) return { title: raw.trim() }
  const [, name, number] = match
  const title = raw.slice(0, match.index).trim()
  const volume = Number(number)
  return {
    title: title || raw.trim(),
    series: { name: name.trim(), volume: Number.isInteger(volume) ? volume : undefined },
  }
}

/** Goodreads writes ISBNs as spreadsheet formulas, `="9782070612758"`, so that
 *  Excel keeps their leading zeros; an empty one is `=""`. */
export const isbnIn = (cell: string | undefined): string | undefined => {
  const digits = (cell ?? '').replace(/[="\s-]/g, '')
  return digits === '' ? undefined : digits
}

/** An ISBN-10 as the ISBN-13 it is printed as. */
const isbn13From10 = (isbn10: string): string | undefined => {
  if (!/^\d{9}[\dX]$/i.test(isbn10)) return undefined
  const body = `978${isbn10.slice(0, 9)}`
  const sum = [...body].reduce(
    (total, digit, index) => total + Number(digit) * (index % 2 === 0 ? 1 : 3),
    0,
  )
  return `${body}${(10 - (sum % 10)) % 10}`
}

/** "2024/05/12", the way every Goodreads date is written. Noon UTC, so the day
 *  reads the same in every time zone. */
export const dateIn = (cell: string | undefined): Date | undefined => {
  const match = (cell ?? '').trim().match(/^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$/)
  if (!match) return undefined
  const [, year, month, day] = match.map(Number)
  const date = new Date(Date.UTC(year, month - 1, day, 12))
  return date.getUTCMonth() === month - 1 ? date : undefined
}

/** What the binding says the object is and where it is held. An audiobook is a
 *  recording, its own record; an ebook is a book held on a screen. Drawn stories
 *  carry no binding of their own on Goodreads ("Paperback" for a manga), so a
 *  comic is only recognized when the binding says so. */
export const formatOf = (
  binding: string | undefined,
): { format: BookFormat; media: BookMedium[] } => {
  const folded = (binding ?? '').toLowerCase()
  if (/audio|mp3|cd/.test(folded)) return { format: 'audiobook', media: [] }
  const media: BookMedium[] = /kindle|ebook|e-book|nook|kobo|digital/.test(folded)
    ? ['digital']
    : ['print']
  if (/manga|tank[oō]bon/.test(folded)) return { format: 'manga', media }
  if (/bande dessin|bd\b/.test(folded)) return { format: 'bande-dessinee', media }
  if (/comic|graphic novel/.test(folded)) return { format: 'comic', media }
  return { format: 'book', media }
}

/** A review as a note: Goodreads stores its reviews as HTML, line breaks as
 *  `<br />`. */
export const noteFrom = (review: string | undefined) =>
  optionally(
    (review ?? '')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/\n{3,}/g, '\n\n')
      .trim()
      .slice(0, 10000),
    ReadingNote,
  )

/** Additional authors are listed apart, comma-separated, translators among
 *  them: only the first author is kept beside the main one. */
const authorsIn = (main: string | undefined): AuthorNameType[] =>
  [optionally(main?.trim(), AuthorName)].filter(isPresent)

const SHELVES: Record<string, GoodreadsShelf> = {
  read: 'read',
  'currently-reading': 'currently-reading',
  'to-read': 'to-read',
}

/** Read a Goodreads library export into rows. `'not-goodreads'` for a file
 *  without the export's headings, `'empty'` for one with no book. A book listed
 *  twice — the same title and author — is one row. */
export const rowsOf = (csv: string): GoodreadsRow[] | UnreadableGoodreadsExport => {
  const [headers, ...body] = csvRowsOf(csv, delimiterOf(csv))
  if (!headers) return 'not-goodreads'
  const trimmed = headers.map((heading) => heading.trim())
  if (!REQUIRED.every((heading) => trimmed.includes(heading))) return 'not-goodreads'
  const at = (row: string[], heading: string) => {
    const index = trimmed.indexOf(heading)
    return index < 0 ? undefined : row[index]?.trim()
  }

  const seen = new Set<string>()
  const rows: GoodreadsRow[] = []
  for (const cells of body) {
    const read = seriesIn(at(cells, 'Title') ?? '')
    const title = optionally(read.title, BookTitle)
    if (!title) continue
    const authors = authorsIn(at(cells, 'Author'))
    const key = shelfKeyOf(title, authors[0])
    if (seen.has(key)) continue
    seen.add(key)

    const series = read.series && {
      name: SeriesName(read.series.name),
      volume: optionally(read.series.volume, VolumeNumber),
    }
    const isbn = isbnIn(at(cells, 'ISBN13')) ?? isbn13From10(isbnIn(at(cells, 'ISBN')) ?? '')
    const rating = Number(at(cells, 'My Rating') ?? 0)
    const shelves = (at(cells, 'Bookshelves') ?? '').split(',').map((shelf) => shelf.trim())
    const shelf = SHELVES[at(cells, 'Exclusive Shelf') ?? ''] ?? 'to-read'
    const { format, media } = formatOf(at(cells, 'Binding'))

    rows.push({
      key,
      title,
      authors,
      series,
      isbn13: optionally(isbn, Isbn13),
      rating: rating > 0 ? optionally(rating, StarRating) : undefined,
      publisher: optionally(at(cells, 'Publisher'), Publisher),
      format,
      media,
      pageCount: optionally(at(cells, 'Number of Pages'), PageCount),
      firstPublishedIn:
        optionally(at(cells, 'Original Publication Year'), Year) ??
        optionally(at(cells, 'Year Published'), Year),
      readOn: dateIn(at(cells, 'Date Read')),
      addedOn: dateIn(at(cells, 'Date Added')),
      shelf,
      dropped: shelves.some((name) => DROPPED_SHELF.test(name)),
      review: noteFrom(at(cells, 'My Review')),
    })
  }
  return rows.length === 0 ? 'empty' : rows
}

/** "Le Sorceleur, tome 1 : Le Dernier Vœu" holds "Le Dernier Vœu": the part
 *  after a colon, which is how French editions title a volume. */
const subtitleOf = (title: string): string | undefined => {
  const parts = title.split(/\s:\s|:\s/)
  return parts.length > 1 ? parts.at(-1)?.trim() : undefined
}

/** How each row stands against the library: held when the reader keeps that
 *  story already (title and author agreeing, or the same ISBN), in the same
 *  language and at the same volume; uncertain when only part of it agrees —
 *  the same title by an author spelled otherwise, a volume titled after its
 *  saga; new otherwise. An uncertain row is left for the reader to decide. */
export const verdictsOf = (
  rows: readonly GoodreadsRow[],
  owned: readonly Book[],
  languageOfIsbn: (isbn: string) => BookLanguage | undefined,
): GoodreadsPreviewRow[] =>
  rows.map((row) => {
    const language = row.isbn13 ? languageOfIsbn(row.isbn13) : undefined
    const held = owned.find(
      (book) =>
        (book.format !== 'audiobook') === (row.format !== 'audiobook') &&
        ((row.isbn13 !== undefined && book.isbn13 === row.isbn13) ||
          (slugify(book.title) === slugify(row.title) &&
            sameAuthor(book.authors[0], row.authors[0]))) &&
        (book.series?.volume === undefined ||
          row.series?.volume === undefined ||
          book.series.volume === row.series.volume) &&
        (language === undefined || book.language === language),
    )
    const coverGuess = row.isbn13
      ? (`https://covers.openlibrary.org/b/isbn/${row.isbn13}-M.jpg?default=false` as CoverUrl)
      : undefined
    if (held)
      return {
        ...row,
        verdict: 'held',
        heldBookId: held.id,
        heldTitle: held.title,
        heldCoverUrl: held.publishedCoverUrl ?? held.kindleCoverUrl,
        coverGuess,
        language,
      }
    const subtitle = subtitleOf(row.title)
    const near = owned.find(
      (book) =>
        (slugify(book.title) === slugify(row.title) &&
          !sameAuthor(book.authors[0], row.authors[0])) ||
        (subtitle !== undefined &&
          slugify(book.title) === slugify(subtitle) &&
          sameAuthor(book.authors[0], row.authors[0])),
    )
    if (near)
      return {
        ...row,
        verdict: 'uncertain',
        heldBookId: near.id,
        heldTitle: near.title,
        heldCoverUrl: near.publishedCoverUrl ?? near.kindleCoverUrl,
        coverGuess,
        language,
      }
    return { ...row, verdict: 'new', coverGuess, language }
  })

/** The figures the preview opens on. */
export const previewOf = (rows: GoodreadsPreviewRow[]): GoodreadsPreview => ({
  rows,
  shelves: {
    read: rows.filter((row) => row.shelf === 'read' && !row.dropped).length,
    reading: rows.filter((row) => row.shelf === 'currently-reading' && !row.dropped).length,
    toRead: rows.filter((row) => row.shelf === 'to-read' && !row.dropped).length,
    dropped: rows.filter((row) => row.dropped).length,
  },
  rated: rows.filter((row) => row.rating !== undefined).length,
  dated: rows.filter((row) => row.readOn !== undefined).length,
  reviewed: rows.filter((row) => row.review !== undefined).length,
})

/** Where a row lands: a wish, or a book with a status. */
export const destinationOf = (
  row: GoodreadsRow,
  choices: Pick<GoodreadsChoices, 'toRead'>,
): 'wish' | 'to-read' | 'reading' | 'read' | 'dropped' => {
  if (row.dropped) return 'dropped'
  if (row.shelf === 'read') return 'read'
  if (row.shelf === 'currently-reading') return 'reading'
  return choices.toRead === 'wishlist' ? 'wish' : 'to-read'
}

/** The record a row writes, with what the reader chose to carry over. The saga
 *  is keyed as a scan keys it, from its printed name and first author. */
export const bookFrom = (
  row: GoodreadsPreviewRow,
  status: 'to-read' | 'reading' | 'read' | 'dropped',
  choices: Pick<GoodreadsChoices, 'keepRatings' | 'keepDates' | 'keepReviews'>,
): NewBook => {
  const author = row.authors[0]
  const finishedAt = status === 'read' ? (choices.keepDates ? row.readOn : undefined) : undefined
  return {
    origin: { kind: 'goodreads' },
    title: row.title,
    authors: row.authors,
    format: row.format,
    media: row.media,
    publisher: row.publisher,
    firstPublishedIn: row.firstPublishedIn,
    pageCount: row.pageCount,
    isbn13: row.isbn13,
    language: row.language,
    series:
      row.series && author
        ? {
            saga: seriesKeyOf(row.series.name, author, row.format),
            name: row.series.name,
            volume: row.series.volume,
            kind: 'main',
          }
        : undefined,
    status,
    // Without its reading date a finished book is dated the day it was shelved
    // on Goodreads, never the night of the import.
    finishedAt: finishedAt ?? (status === 'read' ? row.addedOn : undefined),
    addedAt: row.addedOn,
    rating: choices.keepRatings ? row.rating : undefined,
    note: choices.keepReviews ? row.review : undefined,
  }
}

/** Whether a held book is to be completed by its row: only with what it lacks,
 *  so a second import of the same export never writes the review twice. */
export const completionOf = (held: Book, input: NewBook): NewBook | undefined => {
  const completion: NewBook = {
    ...input,
    rating: held.rating === undefined ? input.rating : undefined,
    note: held.note === undefined ? input.note : undefined,
  }
  const adds =
    completion.rating !== undefined ||
    completion.note !== undefined ||
    (held.status !== 'read' && input.status === 'read')
  return adds ? completion : undefined
}
