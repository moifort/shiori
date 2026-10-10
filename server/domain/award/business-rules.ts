import { editionWatchKeyOf } from '~/domain/awaited-edition/business-rules'
import type { FoundEdition } from '~/domain/awaited-edition/types'
import { shelfKeyOf } from '~/domain/book/business-rules'
import type { Book, BookLanguage, Genre } from '~/domain/book/types'
import { releaseFormatOf } from '~/domain/discovery/business-rules'
import type { ReleaseFormat } from '~/domain/discovery/types'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import { AWARDS, type Award, type AwardedWork, type AwardMention, type FoundWinners } from './types'
import { WINNERS, type WinnerEntry } from './winners'

/** The awards each genre is shown, the genre's own first. Hugo and Nebula crown
 *  science fiction and fantasy alike, so both genres list them. A genre absent
 *  here shows no awards. */
export const AWARDS_BY_GENRE: Partial<Record<Genre, readonly Award[]>> = {
  'science-fiction': ['hugo', 'nebula', 'locus-sf', 'clarke'],
  fantasy: ['world-fantasy', 'locus-fantasy', 'hugo', 'nebula'],
}

/** How much of a genre a reader must have read or be reading before its awards
 *  are offered to them: a single novel read by chance is not a taste. */
export const MIN_GENRE_WEIGHT = 3

/** How many winners the strip shows; the rest are on the full list. */
export const RECENT_COUNT = 12

/** How many genres Découvrir gives a section of award winners: the ones the
 *  reader reads most. */
export const MAX_AWARD_SECTIONS = 3

const AUTHORS_SEPARATOR = ' & '

/** Every winner of an award: the versioned list, then the years the daily pass
 *  found on Wikidata after it. A year the list holds is never taken from the
 *  pass, whose source is not the authority. */
export const winnersOf = (award: Award, found: readonly FoundWinners[]): WinnerEntry[] => {
  const listed = WINNERS[award]
  const years = new Set(listed.map(([year]) => year))
  return [
    ...listed,
    ...found
      .filter((entry) => entry.award === award && !years.has(entry.year))
      .flatMap(({ year, winners }) =>
        winners.map(
          ({ title, authors }) => [year, title, authors.join(AUTHORS_SEPARATOR)] as const,
        ),
      ),
  ]
}

/** The winners of an award's latest ceremony: what Découvrir shows of it. */
export const latestWinnersOf = (award: Award, found: readonly FoundWinners[]): WinnerEntry[] => {
  const winners = winnersOf(award, found)
  const latest = Math.max(...winners.map(([year]) => year))
  return winners.filter(([year]) => year === latest)
}

/** The latest year each award is known to have been given, by the list or by
 *  the daily pass: the pass asks Wikidata only for what comes after it. */
export const latestYearsOf = (found: readonly FoundWinners[]): Record<Award, number> =>
  Object.fromEntries(
    AWARDS.map((award) => [award, Math.max(...winnersOf(award, found).map(([year]) => year))]),
  ) as Record<Award, number>

/** Every work among the rows of these awards, once, its mentions newest first,
 *  the works themselves in the order of their latest award, newest first, and
 *  on one year in the order the awards are given. The rows are every winner
 *  unless told otherwise. */
export const worksOf = (
  awards: readonly Award[],
  rowsOf: (award: Award) => readonly WinnerEntry[] = (award) => WINNERS[award],
): AwardedWork[] => {
  const works = new Map<string, AwardedWork>()
  for (const award of awards)
    for (const [year, title, authors] of rowsOf(award)) {
      const names = authors.split(AUTHORS_SEPARATOR)
      const key = shelfKeyOf(title, names[0])
      const known = works.get(key)
      const mention: AwardMention = { award, year }
      if (known) known.mentions.push(mention)
      else
        works.set(key, {
          key,
          title: BookTitle(title),
          authors: names.map(AuthorName),
          language: 'en',
          mentions: [mention],
        })
    }
  for (const work of works.values()) work.mentions.sort((left, right) => right.year - left.year)
  // On a year two awards crowned different novels, the genre's own award first.
  const rankOf = (work: AwardedWork) =>
    Math.min(
      ...work.mentions
        .filter((mention) => mention.year === latestYearOf(work))
        .map((mention) => awards.indexOf(mention.award)),
    )
  return [...works.values()].sort(
    (left, right) =>
      latestYearOf(right) - latestYearOf(left) ||
      rankOf(left) - rankOf(right) ||
      left.title.localeCompare(right.title),
  )
}

const latestYearOf = (work: AwardedWork) => work.mentions[0]?.year ?? 0

/** The genres with awards, ranked by how much of each the reader has read or is
 *  reading — a book rated four or five stars counting twice — the one read most
 *  recently first on a tie. Only those past `MIN_GENRE_WEIGHT`. */
export const genresOf = (
  books: readonly Pick<Book, 'genre' | 'status' | 'rating' | 'finishedAt' | 'statusChangedAt'>[],
): Genre[] => {
  const weights = new Map<Genre, { weight: number; latest: number }>()
  for (const book of books) {
    if (!book.genre || !AWARDS_BY_GENRE[book.genre]) continue
    if (book.status !== 'read' && book.status !== 'reading') continue
    const entry = weights.get(book.genre) ?? { weight: 0, latest: 0 }
    entry.weight += (book.rating ?? 0) >= 4 ? 2 : 1
    const at = (book.finishedAt ?? book.statusChangedAt)?.getTime() ?? 0
    entry.latest = Math.max(entry.latest, at)
    weights.set(book.genre, entry)
  }
  return [...weights.entries()]
    .filter(([, { weight }]) => weight >= MIN_GENRE_WEIGHT)
    .sort(([, left], [, right]) => right.weight - left.weight || right.latest - left.latest)
    .map(([genre]) => genre)
}

/** The section a work is shown in, among the reader's genres ranked: the first
 *  whose own award crowned it — one no other of those genres shows — else the
 *  first whose awards crowned it at all. A Hugo shared by science fiction and
 *  fantasy is drawn once, where the reader reads most, unless the World
 *  Fantasy says it is fantasy. Undefined for a work none of them crowned. */
export const sectionGenreOf = (
  work: Pick<AwardedWork, 'mentions'>,
  genres: readonly Genre[],
): Genre | undefined => {
  const awardsOf = (genre: Genre) => AWARDS_BY_GENRE[genre] ?? []
  const crowned = (genre: Genre, own: boolean) =>
    work.mentions.some(
      ({ award }) =>
        awardsOf(genre).includes(award) &&
        (!own || genres.every((other) => other === genre || !awardsOf(other).includes(award))),
    )
  return (
    genres.find((genre) => crowned(genre, true)) ?? genres.find((genre) => crowned(genre, false))
  )
}

/** The shared watch a work's edition in one format and language is kept under:
 *  the very one an edition awaited from a scan of it uses, so awaiting a winner
 *  costs no second call. */
export const watchKeyOf = (
  work: Pick<AwardedWork, 'title' | 'authors'>,
  format: ReleaseFormat,
  language: BookLanguage,
): string => editionWatchKeyOf(work, format, language)

type ShelfBook = Pick<Book, 'format' | 'title' | 'authors' | 'audibleAsin' | 'isbn13' | 'status'>

/** Whether a book of the reader's is this work: the edition found — by its
 *  recording, its ISBN, or its title in the language looked up — or the title
 *  it won under. The original title alone would miss every translated copy. */
const isWork = (book: ShelfBook, work: AwardedWork, found: FoundEdition | undefined): boolean => {
  if (found?.asin !== undefined && book.audibleAsin === found.asin) return true
  if (found?.isbn13 !== undefined && book.isbn13 === found.isbn13) return true
  const key = shelfKeyOf(book.title, book.authors[0])
  return (
    key === work.key || (found !== undefined && key === shelfKeyOf(found.title, work.authors[0]))
  )
}

/** Whether the reader holds the work in the format on screen, in any status. */
export const isHeld = (
  work: AwardedWork,
  format: ReleaseFormat,
  found: FoundEdition | undefined,
  books: readonly ShelfBook[],
): boolean =>
  books.some((book) => releaseFormatOf(book.format) === format && isWork(book, work, found))

/** Whether the reader has read the work, in any format. */
export const hasRead = (
  work: AwardedWork,
  found: FoundEdition | undefined,
  books: readonly ShelfBook[],
): boolean => books.some((book) => book.status === 'read' && isWork(book, work, found))
