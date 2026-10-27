import { authorKeyOf } from '~/domain/author/primitives'
import {
  AUTHOR_CORRECTABLE_FIELDS,
  type Author,
  type AuthorCorrectableField,
  type AuthorCorrection,
  type AuthorKey,
  type AuthorSeries,
  type AuthorWork,
  type ShelvedAuthor,
} from '~/domain/author/types'
import { shelfDateOf, shelfOrder, shelfTitleOrder } from '~/domain/book/business-rules'
import type { BookFormat, BookLanguage, ReadingStatus } from '~/domain/book/types'
import { sagaKeyFor, seriesKeyOf } from '~/domain/series/primitives'
import type { SagaKey, SeriesState } from '~/domain/series/types'
import { Count } from '~/domain/shared/primitives'
import type { AuthorName, Count as CountValue } from '~/domain/shared/types'
import { slugify } from '~/utils/slug'

type AuthoredBook = {
  title: string
  authors: AuthorName[]
  series?: { saga: SagaKey }
  rating?: number
  favorite?: boolean
  addedAt: Date
  startedAt?: Date
  finishedAt?: Date
}

type SagaOpinion = { seriesId: SagaKey; rating?: number; favorite?: boolean }

/** Every author the library holds a book of, with what the reader made of them.
 *
 *  A book with several authors is on each of them: the reader who loved
 *  Good Omens loved it by Pratchett and by Gaiman alike. A saga counts for an
 *  author as soon as one of their books belongs to it, so its heart and stars
 *  are theirs too — the saga is their work. */
export const shelvedAuthorsOf = <Book extends AuthoredBook>(
  books: readonly Book[],
  opinions: readonly SagaOpinion[],
): ShelvedAuthor<Book>[] => shelvedPeopleOf(books, opinions, (book) => book.authors, authorKeyOf)

/** Everyone the library credits on a book — its authors, a recording's
 *  narrators — with what the reader made of their books and sagas, one row
 *  per name as `keyOf` folds it, the spelling most books use kept. */
export const shelvedPeopleOf = <
  Book extends Omit<AuthoredBook, 'authors'>,
  Name extends string,
  Key extends string,
>(
  books: readonly Book[],
  opinions: readonly SagaOpinion[],
  namesOf: (book: Book) => readonly Name[],
  keyOf: (name: Name) => Key,
): {
  key: Key
  name: Name
  books: Book[]
  seriesIds: SagaKey[]
  shelvedAt: Date
  favoriteCount: CountValue
  averageRating?: number
}[] => {
  const opinionOf = new Map(opinions.map((opinion) => [opinion.seriesId, opinion]))
  const byKey = new Map<Key, { books: Book[]; spellings: Map<Name, number> }>()
  for (const book of newestShelvedFirst(books)) {
    // A book listing the same person twice is still one book of theirs.
    const keys = new Set<Key>()
    for (const name of namesOf(book)) {
      const key = keyOf(name)
      const known = byKey.get(key) ?? {
        books: [] as Book[],
        spellings: new Map<Name, number>(),
      }
      if (!keys.has(key)) known.books.push(book)
      keys.add(key)
      known.spellings.set(name, (known.spellings.get(name) ?? 0) + 1)
      byKey.set(key, known)
    }
  }
  return [...byKey].map(([key, { books, spellings }]) => {
    const newest = books[0]
    if (!newest) throw new Error('a person is only ever made from a book')
    const seriesIds = [...new Set(books.flatMap((book) => (book.series ? [book.series.saga] : [])))]
    const sagaOpinions = seriesIds.flatMap((id) => opinionOf.get(id) ?? [])
    const ratings = [...books, ...sagaOpinions].flatMap((judged) =>
      judged.rating === undefined ? [] : [judged.rating],
    )
    return {
      key,
      name: mostUsedSpelling(spellings),
      books,
      seriesIds,
      shelvedAt: shelfDateOf(newest),
      favoriteCount: Count(
        [...books, ...sagaOpinions].filter((judged) => judged.favorite === true).length,
      ),
      averageRating:
        ratings.length === 0
          ? undefined
          : ratings.reduce((sum, rating) => sum + rating, 0) / ratings.length,
    }
  })
}

/** An author the reader holds nothing of, as Découvrir offers one a friend
 *  loves: the name it gives, and nothing of the reader's. Null unless the name
 *  folds into the key, so a page is never built for somebody else. Never on the
 *  Authors tab, so the date it is "shelved" on, `now`, orders nothing. */
export const unshelvedAuthorOf = <Book>(
  key: AuthorKey,
  name: AuthorName,
  now: Date,
): ShelvedAuthor<Book> | null =>
  authorKeyOf(name) === key
    ? { key, name, books: [], seriesIds: [], shelvedAt: now, favoriteCount: Count(0) }
    : null

/** The Authors tab's order: the authors the reader loves first. Hearts first,
 *  since a heart is the one mark given on purpose; then the stars' mean; then
 *  how much of theirs the reader holds; then the name, so two authors who tie
 *  on everything keep a stable place between two pages.
 *
 *  Done on the server rather than on the phone because the list is paginated:
 *  ordered on the client, a page landing late would reshuffle what is drawn. */
export const inAuthorOrder = <Author extends ShelvedAuthor<unknown>>(
  authors: readonly Author[],
): Author[] =>
  [...authors].sort(
    (left, right) =>
      right.favoriteCount - left.favoriteCount ||
      (right.averageRating ?? 0) - (left.averageRating ?? 0) ||
      right.books.length - left.books.length ||
      left.name.localeCompare(right.name),
  )

/** The Authors tab by activity, as the Books and Series tabs are ordered: the
 *  author whose newest book was shelved most recently first. Two authors
 *  shelved the same day rank as the Books tab ranks their newest books — by
 *  title — so reading down one list reads down the other; then by name, for
 *  the co-authors of one book. */
export const inActivityOrder = <
  Author extends { name: string; shelvedAt: Date; books: readonly { title: string }[] },
>(
  authors: readonly Author[],
): Author[] =>
  [...authors].sort(
    (left, right) =>
      right.shelvedAt.getTime() - left.shelvedAt.getTime() ||
      shelfTitleOrder(left.books[0]?.title ?? '', right.books[0]?.title ?? '') ||
      left.name.localeCompare(right.name),
  )

/** The words a surname can open with and still belong to it: "Le Guin",
 *  "de La Fontaine", "van Vogt". */
const particles = new Set([
  'd',
  'da',
  'de',
  'del',
  'della',
  'des',
  'di',
  'du',
  'la',
  'le',
  'van',
  'von',
  'der',
  'den',
  'ten',
  'ter',
])

/** The part of an author's name they are filed under, as a bookshop files them:
 *  the surname, a lowercase particle set aside as French does it — Balzac under
 *  B, but Le Guin under L and La Fontaine under L. A single name is its own
 *  surname. */
export const filingNameOf = (name: string): string => {
  const words = name.trim().split(/\s+/)
  let start = words.length - 1
  while (start > 1 && particles.has(stripApostrophe(words[start - 1] ?? '').toLowerCase()))
    start -= 1
  const surname = words.slice(Math.max(start, 0))
  while (surname.length > 1 && isLowercaseParticle(surname[0] ?? '')) surname.shift()
  return surname.join(' ').replace(/^[dl]['’]/i, '')
}

const stripApostrophe = (word: string) => word.replace(/['’].*$/, '')

const isLowercaseParticle = (word: string) =>
  word === word.toLowerCase() && particles.has(stripApostrophe(word))

/** The letter of the alphabet index an author sits under: the first letter of
 *  their filing name, stripped of its accent, or "#" when it is no Latin letter. */
export const indexLetterOf = (name: string): string => {
  const first = filingNameOf(name)
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .charAt(0)
    .toUpperCase()
  return /^[A-Z]$/.test(first) ? first : '#'
}

/** The Authors tab in alphabetical order, as a contact list is: by filing name,
 *  the authors under "#" last, then the whole name between two namesakes. */
export const inNameOrder = <Author extends { name: string }>(
  authors: readonly Author[],
): Author[] =>
  [...authors].sort((left, right) => {
    const leftOther = indexLetterOf(left.name) === '#'
    const rightOther = indexLetterOf(right.name) === '#'
    if (leftOther !== rightOther) return leftOther ? 1 : -1
    return (
      filingNameOf(left.name).localeCompare(filingNameOf(right.name), 'fr', {
        sensitivity: 'base',
      }) || left.name.localeCompare(right.name, 'fr', { sensitivity: 'base' })
    )
  })

/** The authors a view of the tab keeps: every one, or those with a heart. */
export const matchingAuthorFilter = <Author extends { key: AuthorKey; favoriteCount: number }>(
  authors: readonly Author[],
  filter: { favorite?: boolean },
  hearted: ReadonlySet<AuthorKey> = new Set(),
): Author[] =>
  filter.favorite
    ? authors.filter((author) => author.favoriteCount > 0 || hearted.has(author.key))
    : [...authors]

/** The authors the reader hearted themself lead, in the order given: what
 *  "Préférés" lists first, before the hearts their books carry. */
export const heartedFirst = <Author extends { key: AuthorKey }>(
  authors: readonly Author[],
  hearted: ReadonlySet<AuthorKey>,
): Author[] => [
  ...authors.filter((author) => hearted.has(author.key)),
  ...authors.filter((author) => !hearted.has(author.key)),
]

const newestShelvedFirst = <Book extends Omit<AuthoredBook, 'authors'>>(
  books: readonly Book[],
): Book[] => [...books].sort(shelfOrder)

/** The spelling used most, the first met — the newest book — breaking a tie. */
const mostUsedSpelling = <Name extends string>(spellings: ReadonlyMap<Name, number>): Name => {
  let chosen: Name | undefined
  for (const [name, count] of spellings)
    if (chosen === undefined || count > (spellings.get(chosen) ?? 0)) chosen = name
  if (chosen === undefined) throw new Error('a person is only ever made from a spelling')
  return chosen
}

/** The sagas of an author's catalogue the reader holds no volume of, in any
 *  format, each with the id its catalogue would be keyed on in `format`, so a
 *  volume added from the author's page files into the saga the Series tab and
 *  the saga screen know. A saga heard is not one to discover on paper, nor one
 *  read among the recordings: the reader already has it.
 *
 *  A saga the reader holds is recognised by that id, by its folded name, by a
 *  name folded into the other's ("Le Problème à trois corps" and "Trilogie du
 *  Problème à trois corps"), or by its first volume on the reader's shelves: a
 *  saga filed under another spelling of the author, or named otherwise by an
 *  Audible import, keeps another id, and must not come back as one to discover. */
export const sagasNotHeldOf = (
  catalogue: Pick<Author, 'name' | 'series'>,
  held: readonly { saga: SagaKey; name: string; books?: readonly { title: string }[] }[],
  format: BookFormat,
): (AuthorSeries & { saga: SagaKey })[] => {
  const heldIds = new Set(held.map((row) => sagaKeyFor(row.saga, 'book')))
  const heldNames = held.map((saga) => slugify(saga.name))
  const heldTitles = new Set(
    held.flatMap((saga) => (saga.books ?? []).map((book) => slugify(book.title))),
  )
  const isHeld = (saga: AuthorSeries & { saga: SagaKey }) => {
    const name = slugify(saga.name)
    return (
      heldIds.has(sagaKeyFor(saga.saga, 'book')) ||
      heldNames.some((heldName) => namesMeet(name, heldName)) ||
      (saga.firstVolumeTitle !== undefined && heldTitles.has(slugify(saga.firstVolumeTitle)))
    )
  }
  return catalogue.series
    .map((saga) => ({ ...saga, saga: seriesKeyOf(saga.name, catalogue.name, format) }))
    .filter((saga) => !isHeld(saga))
}

/** The format the reader takes an author in: heard when most of their books of
 *  them are recordings, read otherwise. What their page offers the sagas they
 *  hold nothing of in. */
export const preferredFormatOf = (books: readonly { format: BookFormat }[]): BookFormat =>
  books.filter((book) => book.format === 'audiobook').length * 2 > books.length
    ? 'audiobook'
    : 'book'

/** Two folded saga names that are one saga: equal, or one standing whole-word
 *  inside the other. */
const namesMeet = (left: string, right: string): boolean => {
  if (left === '' || right === '') return false
  const within = (outer: string, inner: string) => `-${outer}-`.includes(`-${inner}-`)
  return within(left, right) || within(right, left)
}

/** How many sagas an author's books belong to, a saga read and heard counting
 *  once: the two are kept apart for their spines, but they are one work. */
export const sagaCountOf = (seriesIds: readonly SagaKey[]): number =>
  new Set(seriesIds.map((id) => sagaKeyFor(id, 'book'))).size

/** The books outside any saga of an author's catalogue the reader does not hold,
 *  matched on the folded title against every book of theirs the reader has. */
export const worksNotHeldOf = (
  catalogue: Pick<Author, 'books'>,
  held: readonly { title: string }[],
): AuthorWork[] => {
  const titles = new Set(held.map((book) => slugify(book.title)))
  return catalogue.books.filter((work) => !titles.has(slugify(work.title)))
}

/** The reader's books of an author outside any saga: the read ones first, then
 *  the others, each group keeping the order it came in. */
export const standaloneBooksOf = <Book extends { series?: unknown; status: ReadingStatus }>(
  books: readonly Book[],
): Book[] => {
  const standalone = books.filter((book) => !book.series)
  return [
    ...standalone.filter((book) => book.status === 'read'),
    ...standalone.filter((book) => book.status !== 'read'),
  ]
}

/** The reader's sagas of an author as the page lists them: the ones they have
 *  read into first — in progress or finished — then the ones not started, then
 *  the ones set aside; the most recently shelved first within each. */
export const inPageOrder = <Saga extends { state: SeriesState | null; shelvedAt: Date }>(
  sagas: readonly Saga[],
): Saga[] => {
  const rank = (state: SeriesState | null) =>
    state === 'not-started' ? 1 : state === 'unfollowed' ? 2 : 0
  return [...sagas].sort(
    (left, right) =>
      rank(left.state) - rank(right.state) || right.shelvedAt.getTime() - left.shelvedAt.getTime(),
  )
}

/** The language most of the reader's books of an author are in: the edition the
 *  author's catalogue titles their works for. Undefined when none records one. */
export const mainLanguageOf = (
  books: readonly { language?: BookLanguage }[],
): BookLanguage | undefined => {
  const counts = new Map<BookLanguage, number>()
  for (const { language } of books)
    if (language) counts.set(language, (counts.get(language) ?? 0) + 1)
  let leading: BookLanguage | undefined
  for (const [language, count] of counts)
    if (leading === undefined || count > (counts.get(leading) ?? 0)) leading = language
  return leading
}

/** How long an author without a face waits before Wikipedia is asked again:
 *  a page gains a photograph rarely, and each opening must not pay a lookup. */
export const PORTRAIT_RETRY_DAYS = 30

/** Whether opening the page should ask Wikipedia for the author's portrait:
 *  the catalogue has none, and it was not sought lately. A catalogue built
 *  before the lookup fell back on the author's name was never sought that
 *  way, so it is asked at its next opening. */
export const isPortraitWorthSeeking = (
  author: Pick<Author, 'portraitUrl' | 'portraitSoughtAt'>,
  now: Date,
): boolean => {
  if (author.portraitUrl) return false
  if (!author.portraitSoughtAt) return true
  return now.getTime() - author.portraitSoughtAt.getTime() >= PORTRAIT_RETRY_DAYS * 86_400_000
}

/** A shared catalogue entry a reader may correct by hand: an author's, a
 *  narrator's. `corrected` names the fields written by hand. */
type Correctable<Field extends string> = { corrected?: Field[]; portraitSoughtAt?: Date }

/** An entry asked of the world again, keeping what readers corrected by hand
 *  on the stored one — even a field they cleared: the model was wrong on it
 *  once, and its next answer is no better source. */
export const keepingCorrectionsOf = <Field extends string, Entry extends Correctable<Field>>(
  fresh: Entry,
  previous: Entry | null,
): Entry => {
  const corrected = previous?.corrected
  if (!previous || !corrected?.length) return fresh
  const kept: Record<string, unknown> = { ...fresh, corrected }
  const before: Record<string, unknown> = previous
  for (const field of corrected) {
    if (before[field] === undefined) delete kept[field]
    else kept[field] = before[field]
  }
  // A face chosen by hand is no face to seek.
  if (corrected.includes('portraitUrl' as Field)) delete kept.portraitSoughtAt
  return kept as Entry
}

/** An entry with a reader's correction written in, each field it names among
 *  `fields` marked as corrected for good. */
export const withCorrectionOf = <Field extends string, Entry extends Correctable<Field>>(
  fields: readonly Field[],
  entry: Entry,
  correction: Partial<Record<Field, unknown>>,
): Entry => {
  const named = fields.filter((field) => field in correction)
  const written = {
    ...entry,
    corrected: [...new Set([...(entry.corrected ?? []), ...named])],
  } as Record<string, unknown>
  for (const field of named) {
    if (correction[field] === undefined) delete written[field]
    else written[field] = correction[field]
  }
  if (named.includes('portraitUrl' as Field)) delete written.portraitSoughtAt
  return written as Entry
}

/** An author's catalogue asked of the world again, keeping what readers
 *  corrected by hand on the stored one. */
export const keepingCorrections = (fresh: Author, previous: Author | null): Author =>
  keepingCorrectionsOf<AuthorCorrectableField, Author>(fresh, previous)

/** An author's catalogue with a reader's correction written in, each field it
 *  names marked as corrected for good. */
export const withCorrection = (author: Author, correction: AuthorCorrection): Author =>
  withCorrectionOf(AUTHOR_CORRECTABLE_FIELDS, author, correction)
