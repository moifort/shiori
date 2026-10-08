import { editionWatchKeyOf, stateOf } from '~/domain/awaited-edition/business-rules'
import type { EditionWatch, FoundEdition } from '~/domain/awaited-edition/types'
import { shelfKeyOf } from '~/domain/book/business-rules'
import type { Book, BookLanguage, Genre } from '~/domain/book/types'
import { releaseFormatOf, WATCH_EVERY_MS } from '~/domain/discovery/business-rules'
import type { ReleaseFormat } from '~/domain/discovery/types'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { Award, AwardedWork, AwardMention } from './types'
import { WINNERS } from './winners'

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

/** A winner nobody found in a language is looked up again after this long: an
 *  old novel untranslated for decades rarely changes overnight. */
export const UNFOUND_WATCH_EVERY_MS = 60 * 86_400_000

/** How long a genre stays watched after the last reader looked at it. */
export const INTEREST_LASTS_MS = 90 * 86_400_000

/** A look at the winners renews the genre's interest at most once a day. */
export const INTEREST_RENEWED_AFTER_MS = 86_400_000

const AUTHORS_SEPARATOR = ' & '

/** Every work that won one of these awards, once, its mentions newest first,
 *  the works themselves in the order of their latest award, newest first, and
 *  on one year in the order the awards are given. */
export const worksOf = (awards: readonly Award[]): AwardedWork[] => {
  const works = new Map<string, AwardedWork>()
  for (const award of awards)
    for (const [year, title, authors] of WINNERS[award]) {
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

/** A watch the hourly pass is to look up: never looked up, or looked up too
 *  long ago for what it found. One found out is never looked up again. */
export const isDue = (watch: EditionWatch | undefined, now: Date, today: string): boolean => {
  if (!watch) return true
  if (stateOf(watch.found, watch.format, today) === 'available') return false
  const every = watch.found ? WATCH_EVERY_MS : UNFOUND_WATCH_EVERY_MS
  return now.getTime() - watch.checkedAt.getTime() >= every
}
