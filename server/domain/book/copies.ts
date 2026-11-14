// One story, several copies: telling two records of the same book apart from
// two books, by title and author, and joining a copy that arrives on a medium
// the reader lacks into the record they keep. Split from business-rules.ts.

import { MAX_NOTE_LENGTH, ReadingNote } from '~/domain/book/primitives'
import type {
  Book,
  BookFormat,
  BookLanguage,
  BookMedium,
  ReadingStatus,
  SeriesMembership,
} from '~/domain/book/types'
import { BOOK_MEDIA } from '~/domain/book/types'
import { slugify } from '~/utils/slug'

/** The title and first author folded together: whether the reader already owns
 *  this story, loosely and across editions. A novel scanned from the printed
 *  edition is the same story as its Audible recording, and a friend's copy of
 *  it is one the reader already has.
 *
 *  Loose on purpose, and not an identity: the ASIN of an imported record is the
 *  precise answer to "which record is this exact Audible title", which is what
 *  the sync writes a status into. */
export const shelfKeyOf = (title: string, author: string | undefined): string =>
  `${slugify(title)}--${slugify(author ?? '')}`

export const shelfKeysOf = (books: readonly Book[]): Set<string> =>
  new Set(books.map((book) => shelfKeyOf(book.title, book.authors[0])))

/** Whether two names say the same story, looser than the shelf key: the same
 *  title, by authors who agree (`sameAuthor`). A spine prints "Barjavel" where
 *  the record says "René Barjavel", and a photo misreads "WILLIAM GIBSON" as
 *  "ILLIAM GIBSON": keyed on the whole name, a shelf photo offered books the
 *  reader already kept, ticked, and added them twice. Only compared, never
 *  stored — the keys kept in Firestore (awaited editions, awards, suggestions)
 *  stay on `shelfKeyOf`. */
export const sameStory = (
  left: { title: string; author?: string },
  right: { title: string; author?: string },
): boolean => slugify(left.title) === slugify(right.title) && sameAuthor(left.author, right.author)

/** Whether the reader already keeps this story, under any record. */
export const keepsStory = (
  books: readonly { title: string; authors: readonly string[] }[],
  story: { title: string; author?: string },
): boolean => books.some((book) => sameStory({ title: book.title, author: book.authors[0] }, story))

/** Whether two spellings name one author: the same last name, and first names
 *  that agree where both are given — one letter apart at most, a misread
 *  initial. "Barjavel" is René Barjavel; Brian Herbert is not Frank Herbert. */
export const sameAuthor = (left: string | undefined, right: string | undefined): boolean => {
  const [a, b] = [namePartsOf(left), namePartsOf(right)]
  if (a.length === 0 || b.length === 0) return a.length === b.length
  if (a.at(-1) !== b.at(-1)) return false
  const [givenA, givenB] = [a.slice(0, -1).join(''), b.slice(0, -1).join('')]
  return givenA === '' || givenB === '' || lettersApart(givenA, givenB) <= 1
}

/** How a store, a pasted link or a picked candidate names the author beside a
 *  title: across a dash set apart by spaces, or in brackets at the end. A
 *  comma or a colon is no such mark — "Moi, Christiane F." is the title of
 *  Christiane F.'s book. */
const AUTHOR_DASH = /\s+[-–—]\s+/gu
const AUTHOR_IN_BRACKETS = /^(.+?)\s*\(([^()]+)\)$/u

/** The title without one of its own authors named beside it, before or after:
 *  "La Horde du Contrevent — Alain Damasio", "Damasio - La Horde du
 *  Contrevent" and "La Horde du Contrevent (Alain Damasio)" by Alain Damasio
 *  are "La Horde du Contrevent". Unchanged when what stands beside the dash is
 *  no author of the book (`sameAuthor`): "Dune — Le Messie" keeps its dash.
 *  What it returns is a part of the title, never empty, so a checked title
 *  stays one. */
export const titleWithoutAuthor = <Title extends string>(
  title: Title,
  authors: readonly string[],
): Title => {
  const byItsAuthor = (name: string) => authors.some((author) => sameAuthor(name, author))
  const bracketed = title.match(AUTHOR_IN_BRACKETS)
  if (bracketed && byItsAuthor(bracketed[2])) return bracketed[1].trim() as Title
  return (dashSplitsOf(title).find(({ named }) => byItsAuthor(named))?.rest ?? title) as Title
}

/** Every way to read a title as a name across a dash from the rest: the name
 *  last, cut at the last dash, then the name first, cut at the first. */
const dashSplitsOf = (title: string): { rest: string; named: string }[] => {
  const dashes = [...title.matchAll(AUTHOR_DASH)]
  const [first, last] = [dashes[0], dashes.at(-1)]
  if (!first || !last) return []
  const before = (dash: RegExpExecArray) => title.slice(0, dash.index).trim()
  const after = (dash: RegExpExecArray) => title.slice(dash.index + dash[0].length).trim()
  return [
    { rest: before(last), named: after(last) },
    { rest: after(first), named: before(first) },
  ].filter(({ rest, named }) => rest !== '' && named !== '')
}

const namePartsOf = (name: string | undefined) =>
  slugify(name ?? '')
    .split('-')
    .filter(Boolean)

/** How many letters to change, add or drop to turn one word into the other. */
export const lettersApart = (left: string, right: string): number => {
  let previous = Array.from({ length: right.length + 1 }, (_, index) => index)
  for (let i = 1; i <= left.length; i++) {
    const current = [i]
    for (let j = 1; j <= right.length; j++)
      current[j] = Math.min(
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + (left[i - 1] === right[j - 1] ? 0 : 1),
      )
    previous = current
  }
  return previous[right.length]
}

/** One copy the reader keeps of a story: what tells it from another volume or
 *  another language under the same title. */
export type ShelfCopy = { volume?: number; language?: BookLanguage }

/** The reader's books by shelf key, as an import checks a title against them. */
export type Shelf = ReadonlyMap<string, readonly ShelfCopy[]>

export const shelfOf = (books: readonly Book[]): Shelf => {
  const shelf = new Map<string, ShelfCopy[]>()
  for (const book of books) {
    const key = shelfKeyOf(book.title, book.authors[0])
    shelf.set(key, [
      ...(shelf.get(key) ?? []),
      { volume: book.series?.volume, language: book.language },
    ])
  }
  return shelf
}

/** Whether the reader already keeps this title, by its shelf key — except that
 *  a saga whose volumes share one title ("Primal Hunter" 4, 5 and 6 on Audible)
 *  is told apart by volume, and a recording in English from the French one by
 *  language. A side that does not say matches: the check stays as loose as the
 *  key wherever nothing tells two copies apart. */
export const keepsCopyOf = (
  shelf: Shelf,
  candidate: { title: string; author?: string; volume?: number; language?: BookLanguage },
): boolean =>
  (shelf.get(shelfKeyOf(candidate.title, candidate.author)) ?? []).some(
    (copy) => agrees(copy.volume, candidate.volume) && agrees(copy.language, candidate.language),
  )

const agrees = <T>(kept: T | undefined, candidate: T | undefined) =>
  kept === undefined || candidate === undefined || kept === candidate

/** The record the reader already keeps of a book about to be added: the same
 *  story by its shelf key, or the same edition by its ISBN, which still matches
 *  when the title was read differently off the cover. The earliest on the shelf
 *  wins — the copy the reader thinks of as theirs.
 *
 *  A warning, never a refusal: two editions of one story — the paperback and
 *  the recording — are a library some readers keep on purpose. */
export const copyOf = <T extends Book>(
  books: readonly T[],
  candidate: { title: string; authors: readonly string[]; isbn13?: string },
): T | undefined => {
  const story = { title: candidate.title, author: candidate.authors[0] }
  return books
    .filter(
      (book) =>
        sameStory({ title: book.title, author: book.authors[0] }, story) ||
        (candidate.isbn13 !== undefined && book.isbn13 === candidate.isbn13),
    )
    .toSorted((a, b) => a.addedAt.getTime() - b.addedAt.getTime())[0]
}

/** Where a book of this format is held, from what a source said of it: a
 *  recording is heard, so it is held on neither; a read book is on paper unless
 *  something said otherwise. Always in the order paper, screen, so two records
 *  held the same way compare equal. */
export const mediaFor = (format: BookFormat, media: readonly BookMedium[] = []): BookMedium[] => {
  if (format === 'audiobook') return []
  const held = BOOK_MEDIA.filter((medium) => media.includes(medium))
  return held.length > 0 ? held : ['print']
}

/** The record a book arriving on another medium joins, rather than doubling:
 *  the same story by `sameStory` or the same edition by its ISBN, read
 *  rather than heard, in the same volume and language wherever both say, and
 *  not yet held on every medium the arrival brings. The paperback scanned after
 *  the Kindle copy is one book, not two; a French paperback and an English
 *  Kindle copy are two editions, as their sagas are. The earliest on the shelf
 *  wins, as for `copyOf`. */
export const recordJoinedBy = <T extends Book>(
  books: readonly T[],
  arriving: Pick<Book, 'title' | 'authors' | 'isbn13' | 'format' | 'media' | 'language'> & {
    series?: Pick<SeriesMembership, 'volume'>
  },
): T | undefined => {
  if (arriving.format === 'audiobook') return undefined
  const story = { title: arriving.title, author: arriving.authors[0] }
  return books
    .filter(
      (book) =>
        book.format !== 'audiobook' &&
        (sameStory({ title: book.title, author: book.authors[0] }, story) ||
          (arriving.isbn13 !== undefined && book.isbn13 === arriving.isbn13)) &&
        agrees(book.series?.volume, arriving.series?.volume) &&
        agrees(book.language, arriving.language) &&
        arriving.media.some((medium) => !book.media.includes(medium)),
    )
    .toSorted((a, b) => a.addedAt.getTime() - b.addedAt.getTime())[0]
}

/** How far along a reading each status is, for two copies of one book to keep
 *  the furthest: finished beats dropped, which beats begun, which beats the
 *  pile. */
const PROGRESS: Record<ReadingStatus, number> = { 'to-read': 0, reading: 1, dropped: 2, read: 3 }

const earliest = (...dates: (Date | undefined)[]): Date | undefined =>
  dates.filter(isDefined).toSorted((a, b) => a.getTime() - b.getTime())[0]

export const latest = (...dates: (Date | undefined)[]): Date | undefined =>
  dates.filter(isDefined).toSorted((a, b) => b.getTime() - a.getTime())[0]

const isDefined = <T>(value: T | undefined): value is T => value !== undefined

/** Two copies of one book — on paper and on a screen — as the one record the
 *  reader keeps of it.
 *
 *  `kept` names the record: its id, and every fact it already states. `other`
 *  fills what `kept` leaves blank, and lends a drawn format (manga, comic) over
 *  the plain `book` a Kindle title is always filed as. Where both said
 *  something about the reading, the furthest along wins: the furthest status,
 *  the earliest start and the latest finish, the higher rating, either heart,
 *  both notes one after the other. A book either copy hid stays hidden. */
export const mergedCopies = (kept: Book, other: Book, now: Date): Book => {
  const format = kept.format === 'book' ? other.format : kept.format
  const status = PROGRESS[other.status] > PROGRESS[kept.status] ? other.status : kept.status
  const finishing = [kept, other].filter((copy) => copy.status === 'read')
  const hearted = [kept, other].filter((copy) => copy.favorite)
  const notes = [kept.note, other.note].filter(isDefined)
  const ratings = [kept.rating, other.rating].filter(isDefined)
  return {
    ...other,
    ...withoutAbsent(kept),
    format,
    media: mediaFor(format, [...kept.media, ...other.media]),
    authors: kept.authors.length > 0 ? kept.authors : other.authors,
    subgenres: kept.subgenres.length > 0 ? kept.subgenres : other.subgenres,
    narrators: kept.narrators.length > 0 ? kept.narrators : other.narrators,
    status,
    rating: ratings.toSorted((a, b) => b - a)[0],
    favorite: hearted.length > 0 ? true : undefined,
    favoritedAt: earliest(...hearted.map((copy) => copy.favoritedAt)),
    note: notes.length > 0 ? ReadingNote(notes.join('\n\n').slice(0, MAX_NOTE_LENGTH)) : undefined,
    hidden: kept.hidden || other.hidden,
    // The record was added first: how it reached the library stays its story,
    // unknown included.
    origin: kept.origin,
    // Described if either copy was: the record keeps the facts of the one that was.
    awaitingDescription: kept.awaitingDescription && other.awaitingDescription ? true : undefined,
    addedAt: earliest(kept.addedAt, other.addedAt) ?? kept.addedAt,
    startedAt: status === 'to-read' ? undefined : earliest(kept.startedAt, other.startedAt),
    finishedAt: latest(...finishing.map((copy) => copy.finishedAt)),
    statusChangedAt: latest(kept.statusChangedAt, other.statusChangedAt),
    updatedAt: now,
  }
}

export const withoutAbsent = <T extends object>(record: T): Partial<T> =>
  Object.fromEntries(
    Object.entries(record).filter(([, value]) => value !== undefined),
  ) as Partial<T>
