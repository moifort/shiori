import { authorKeyOf } from '~/domain/author/primitives'
import type {
  Author,
  AuthorKey,
  AuthorSeries,
  AuthorWork,
  ShelvedAuthor,
} from '~/domain/author/types'
import { shelfDateOf } from '~/domain/book/business-rules'
import type { BookFormat, BookLanguage, ReadingStatus } from '~/domain/book/types'
import { isAudioSeries, seriesIdFor, seriesKeyOf } from '~/domain/series/primitives'
import type { SeriesId, SeriesState } from '~/domain/series/types'
import { Count } from '~/domain/shared/primitives'
import type { AuthorName } from '~/domain/shared/types'
import { slugify } from '~/utils/slug'

type AuthoredBook = {
  authors: AuthorName[]
  series?: { id: SeriesId }
  rating?: number
  favorite?: boolean
  addedAt: Date
  startedAt?: Date
  finishedAt?: Date
}

type SagaOpinion = { seriesId: SeriesId; rating?: number; favorite?: boolean }

/** Every author the library holds a book of, with what the reader made of them.
 *
 *  A book with several authors is on each of them: the reader who loved
 *  Good Omens loved it by Pratchett and by Gaiman alike. A saga counts for an
 *  author as soon as one of their books belongs to it, so its heart and stars
 *  are theirs too — the saga is their work. */
export const shelvedAuthorsOf = <Book extends AuthoredBook>(
  books: readonly Book[],
  opinions: readonly SagaOpinion[],
): ShelvedAuthor<Book>[] => {
  const opinionOf = new Map(opinions.map((opinion) => [opinion.seriesId, opinion]))
  const byKey = new Map<AuthorKey, { books: Book[]; spellings: Map<AuthorName, number> }>()
  for (const book of newestShelvedFirst(books)) {
    // A book listing the same author twice is still one book of theirs.
    const keys = new Set<AuthorKey>()
    for (const name of book.authors) {
      const key = authorKeyOf(name)
      const known = byKey.get(key) ?? {
        books: [] as Book[],
        spellings: new Map<AuthorName, number>(),
      }
      if (!keys.has(key)) known.books.push(book)
      keys.add(key)
      known.spellings.set(name, (known.spellings.get(name) ?? 0) + 1)
      byKey.set(key, known)
    }
  }
  return [...byKey].map(([key, { books, spellings }]) => {
    const seriesIds = [...new Set(books.flatMap((book) => (book.series ? [book.series.id] : [])))]
    const sagaOpinions = seriesIds.flatMap((id) => opinionOf.get(id) ?? [])
    const ratings = [...books, ...sagaOpinions].flatMap((judged) =>
      judged.rating === undefined ? [] : [judged.rating],
    )
    return {
      key,
      name: mostUsedSpelling(spellings),
      books,
      seriesIds,
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
export const matchingAuthorFilter = <Author extends { favoriteCount: number }>(
  authors: readonly Author[],
  filter: { favorite?: boolean },
): Author[] =>
  filter.favorite ? authors.filter((author) => author.favoriteCount > 0) : [...authors]

const newestShelvedFirst = <Book extends AuthoredBook>(books: readonly Book[]): Book[] =>
  [...books].sort((left, right) => shelfDateOf(right).getTime() - shelfDateOf(left).getTime())

/** The spelling used most, the first met — the newest book — breaking a tie. */
const mostUsedSpelling = (spellings: ReadonlyMap<AuthorName, number>): AuthorName => {
  let chosen: AuthorName | undefined
  for (const [name, count] of spellings)
    if (chosen === undefined || count > (spellings.get(chosen) ?? 0)) chosen = name
  if (chosen === undefined) throw new Error('an author is only ever made from a spelling')
  return chosen
}

/** The sagas of an author's catalogue the reader holds no volume of in one
 *  format, each with the id its catalogue would be keyed on in that format, so a
 *  volume added from the author's page files into the saga the Series tab and
 *  the saga screen know. A saga read on paper and never heard is one to
 *  discover among the recordings: the saga heard is a saga of its own.
 *
 *  A saga the reader holds is recognised by that id, by its folded name, by a
 *  name folded into the other's ("Le Problème à trois corps" and "Trilogie du
 *  Problème à trois corps"), or by its first volume on the reader's shelves: a
 *  saga filed under another spelling of the author, or named otherwise by an
 *  Audible import, keeps another id, and must not come back as one to discover. */
export const sagasNotHeldOf = (
  catalogue: Pick<Author, 'name' | 'series'>,
  held: readonly { id: SeriesId; name: string; books?: readonly { title: string }[] }[],
  format: BookFormat,
): (AuthorSeries & { id: SeriesId })[] => {
  const heard = format === 'audiobook'
  const sameFormat = held.filter((saga) => isAudioSeries(saga.id) === heard)
  const heldIds = new Set(sameFormat.map((saga) => saga.id))
  const heldNames = sameFormat.map((saga) => slugify(saga.name))
  const heldTitles = new Set(
    sameFormat.flatMap((saga) => (saga.books ?? []).map((book) => slugify(book.title))),
  )
  const isHeld = (saga: AuthorSeries & { id: SeriesId }) => {
    const name = slugify(saga.name)
    return (
      heldIds.has(saga.id) ||
      heldNames.some((heldName) => namesMeet(name, heldName)) ||
      (saga.firstVolumeTitle !== undefined && heldTitles.has(slugify(saga.firstVolumeTitle)))
    )
  }
  return catalogue.series
    .map((saga) => ({ ...saga, id: seriesKeyOf(saga.name, catalogue.name, format) }))
    .filter((saga) => !isHeld(saga))
}

/** Two folded saga names that are one saga: equal, or one standing whole-word
 *  inside the other. */
const namesMeet = (left: string, right: string): boolean => {
  if (left === '' || right === '') return false
  const within = (outer: string, inner: string) => `-${outer}-`.includes(`-${inner}-`)
  return within(left, right) || within(right, left)
}

/** How many sagas an author's books belong to, a saga read and heard counting
 *  once: the two are kept apart for their spines, but they are one work. */
export const sagaCountOf = (seriesIds: readonly SeriesId[]): number =>
  new Set(seriesIds.map((id) => seriesIdFor(id, 'book'))).size

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
