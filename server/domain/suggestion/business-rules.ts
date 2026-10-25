import type { Book, StarRating } from '~/domain/book/types'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { Language } from '~/domain/shared/language'
import { slugify } from '~/utils/slug'
import type {
  Dismissal,
  DismissalReason,
  ReferenceRank,
  Suggestion,
  SuggestionQueue,
  SuggestionReference,
} from './types'

/** How many suggestions the model is asked for: enough that the checks and the
 *  reader's dismissals leave the line full for the month. */
export const ASKED_COUNT = 20

/** How many lines of the library the model reads at most: the best ranked
 *  first, so a library of any size costs the same. */
export const MAX_DIGEST_LINES = 300

/** How many dismissals the model is told: the latest ones. Every one is still
 *  filtered out, however old. */
export const TOLD_DISMISSALS = 100

/** How the digest heads each kind of dismissal: what the reader does not
 *  like, a taste the model steers clear of, then what they merely passed on. */
const DISMISSAL_TITLES: readonly (readonly [DismissalReason, string])[] = [
  ['disliked', "Déjà proposés, n'aime pas ce genre de livre"],
  ['not-interested', 'Déjà proposés, pas intéressé'],
]

/** The month a selection is titled after: `YYYY-MM`, in UTC. */
export const monthOf = (now: Date): string => now.toISOString().slice(0, 7)

const dayOf = (date: Date): string => date.toISOString().slice(0, 10)

/** Whether the model is asked, when the reader opens Découvrir: no selection
 *  yet, none for this month, or one written in another language than the
 *  app's — never twice the same day. A month whose selection ran out stays
 *  empty until the next: there is no refill. */
export const shouldGenerate = (
  queue: Pick<SuggestionQueue, 'month' | 'generatedAt' | 'language'> | undefined,
  now: Date,
  language: Language,
): boolean => {
  if (!queue) return true
  if (dayOf(queue.generatedAt) === dayOf(now)) return false
  return queue.month !== monthOf(now) || queue.language !== language
}

/** The alert the monthly pass sends once the month's discoveries are made. */
export const discoveriesAlertOf = (language: Language): { title: string; body: string } =>
  language === 'fr'
    ? { title: 'Nouvelles découvertes', body: 'Voici les nouvelles découvertes de ce mois-ci.' }
    : { title: 'New discoveries', body: "Here are this month's new discoveries." }

/** How long a selection is taken to be on its way: a generation runs about a
 *  minute, two at most; past five, the instance that ran it is gone. */
export const GENERATION_WINDOW_MS = 5 * 60 * 1000

/** Where the month's selection stands for a reader in the app's language:
 *  made for this month, being made, or none. */
export const statusOf = (
  queue: Pick<SuggestionQueue, 'month' | 'language' | 'generatingSince'> | undefined,
  now: Date,
  language: Language,
): 'ready' | 'searching' | 'none' => {
  const current = queue?.month === monthOf(now) && queue.language === language
  const generating =
    queue?.generatingSince !== undefined &&
    now.getTime() - queue.generatingSince.getTime() < GENERATION_WINDOW_MS
  if (generating && !current) return 'searching'
  if (queue?.month === monthOf(now)) return 'ready'
  return 'none'
}

/** A heart, then stars, best first. */
type Tier = 'favorite' | '5' | '4' | '3' | 'low'
const TIERS: readonly Tier[] = ['favorite', '5', '4', '3', 'low']
const TIER_TITLES: Record<Tier, string> = {
  favorite: '♥ Coups de cœur',
  '5': '★★★★★ 5 étoiles',
  '4': '★★★★ 4 à 4,5 étoiles',
  '3': '★★★ 3 à 3,5 étoiles',
  low: '★–★★ Déçu',
}

const tierOf = (
  favorite: boolean | undefined,
  rating: StarRating | undefined,
): Tier | undefined => {
  if (favorite) return 'favorite'
  if (rating === undefined) return undefined
  if (rating >= 5) return '5'
  if (rating >= 4) return '4'
  if (rating >= 3) return '3'
  return 'low'
}

type DigestLine = { tier: Tier | 'dropped'; text: string; sagaWide: boolean }

const authorsOf = (book: Pick<Book, 'authors'>) => book.authors.join(', ')

/** The reader's library as the model reads it: by tier, a book ranked by its
 *  own heart or stars, a read volume with none by its saga's — as `lovedRank`
 *  does — the sagas rated as a whole listed apart under each tier, a volume
 *  ranked apart from its saga on its own line. Then the dropped, and the
 *  latest dismissed suggestions. Read books ranked by nothing, the pile and
 *  the readings in progress are left out: the server excludes them anyway. */
export const tasteDigestOf = (
  books: readonly Book[],
  opinions: readonly SeriesOpinion[],
  dismissals: readonly Dismissal[],
): string => {
  const opinionOf = new Map(opinions.map((opinion) => [opinion.seriesId, opinion]))
  const lines: DigestLine[] = []
  const sagas = Map.groupBy(
    books.filter((book) => book.series),
    (book) => book.series?.id ?? '',
  )
  for (const book of books.filter((book) => !book.series)) {
    const line = `« ${book.title} » — ${authorsOf(book)}`
    if (book.status === 'dropped') lines.push({ tier: 'dropped', text: line, sagaWide: false })
    const tier = tierOf(book.favorite, book.rating)
    if (tier && book.status !== 'dropped') lines.push({ tier, text: line, sagaWide: false })
  }
  for (const [seriesId, volumes] of sagas) {
    const first = volumes[0]
    if (!first?.series) continue
    const name = `« ${first.series.name} » — ${authorsOf(first)}`
    if (volumes.some((volume) => volume.status === 'dropped'))
      lines.push({
        tier: 'dropped',
        text: `${name} (série abandonnée en cours de route)`,
        sagaWide: true,
      })
    const opinion = opinionOf.get(seriesId as SeriesOpinion['seriesId'])
    const sagaTier = tierOf(opinion?.favorite, opinion?.rating)
    const read = volumes.filter((volume) => volume.status === 'read')
    const borrowing = read.filter((volume) => !tierOf(volume.favorite, volume.rating))
    if (sagaTier)
      lines.push({
        tier: sagaTier,
        text: `${name} · ${read.length} tome(s) lu(s)${borrowing.length ? ` (dont ${borrowing.length} sans note propre)` : ''}`,
        sagaWide: true,
      })
    for (const volume of volumes) {
      const tier = tierOf(volume.favorite, volume.rating)
      if (!tier || tier === sagaTier) continue
      const number = volume.series?.volume ? `tome ${volume.series.volume}` : 'un tome'
      lines.push({
        tier,
        text: `« ${volume.title} » — ${authorsOf(volume)} (${number} de ${first.series.name})`,
        sagaWide: false,
      })
    }
  }
  const kept = [...TIERS, 'dropped' as const]
    .flatMap((tier) => [
      ...lines.filter((line) => line.tier === tier && !line.sagaWide),
      ...lines.filter((line) => line.tier === tier && line.sagaWide),
    ])
    .slice(0, MAX_DIGEST_LINES)
  const sections = TIERS.flatMap((tier) => {
    const own = kept.filter((line) => line.tier === tier && !line.sagaWide)
    const wide = kept.filter((line) => line.tier === tier && line.sagaWide)
    if (own.length === 0 && wide.length === 0) return []
    return [
      [
        `## ${TIER_TITLES[tier]}`,
        ...own.map((line) => `- ${line.text}`),
        ...(wide.length
          ? ['Et ces séries, notées dans leur ensemble :', ...wide.map((line) => `- ${line.text}`)]
          : []),
      ].join('\n'),
    ]
  })
  const dropped = kept.filter((line) => line.tier === 'dropped')
  if (dropped.length)
    sections.push(['## ✗ Abandonnés', ...dropped.map((line) => `- ${line.text}`)].join('\n'))
  const told = [...dismissals]
    .sort((left, right) => right.dismissedAt.getTime() - left.dismissedAt.getTime())
    .slice(0, TOLD_DISMISSALS)
  for (const [reason, title] of DISMISSAL_TITLES) {
    const said = told.filter((dismissal) => (dismissal.reason ?? 'not-interested') === reason)
    if (said.length)
      sections.push(
        [
          `## ${title}`,
          ...said.map((dismissal) => `- « ${dismissal.title} » — ${dismissal.authors.join(', ')}`),
        ].join('\n'),
      )
  }
  return sections.join('\n\n')
}

/** How the reader reads, for the model to suggest books they can have: their
 *  formats and languages, the commonest first. */
export const readerProfileOf = (books: readonly Pick<Book, 'format' | 'language'>[]) => {
  const share = <T extends string>(values: readonly T[]) =>
    [...Map.groupBy(values, (value) => value)]
      .map(([value, all]) => ({ value, share: all.length / values.length }))
      .sort((left, right) => right.share - left.share)
  return {
    formats: share(books.map((book) => book.format)),
    languages: share(books.map((book) => book.language ?? 'fr')),
  }
}

/** The surname a name is filed under: the last word, folded. */
const surnameOf = (author: string): string => slugify(author).split('-').pop() ?? ''

/** Whether the reader holds this book in any status and format: one of their
 *  books under its title or its original title, by an author of the same
 *  surname — "J. R. R. Tolkien" and "Tolkien" agree. */
export const isHeld = (
  suggestion: Pick<Suggestion, 'title' | 'originalTitle' | 'authors'>,
  books: readonly Pick<Book, 'title' | 'authors'>[],
): boolean => {
  const titles = new Set([slugify(suggestion.title), slugify(suggestion.originalTitle)])
  const surnames = new Set(suggestion.authors.map(surnameOf))
  return books.some(
    (book) =>
      titles.has(slugify(book.title)) &&
      book.authors.some((author) => surnames.has(surnameOf(author))),
  )
}

/** The suggestions the line may show: not held, not dismissed, in the order
 *  the model ranked them. */
export const shownOf = (
  suggestions: readonly Suggestion[],
  books: readonly Pick<Book, 'title' | 'authors'>[],
  dismissedKeys: ReadonlySet<string>,
): Suggestion[] =>
  suggestions.filter(
    (suggestion) => !dismissedKeys.has(suggestion.key) && !isHeld(suggestion, books),
  )

/** The reader's books a suggestion draws on, matched by title — a saga by its
 *  name — each once, in the order the model cited them. A title that matches
 *  nothing is left out; the reason keeps it. */
export const referencesOf = (
  suggestion: Pick<Suggestion, 'references'>,
  books: readonly Book[],
  opinions: readonly SeriesOpinion[],
): SuggestionReference[] => {
  const opinionOf = new Map(opinions.map((opinion) => [opinion.seriesId, opinion]))
  const found: SuggestionReference[] = []
  for (const cited of suggestion.references) {
    const slug = slugify(cited)
    if (!slug) continue
    const book = books.find((candidate) => slugify(candidate.title) === slug)
    const saga = book
      ? undefined
      : books.filter((candidate) => candidate.series && slugify(candidate.series.name) === slug)
    const reference = book
      ? referenceOfBook(book, opinionOf)
      : saga?.length
        ? referenceOfSaga(saga, opinionOf)
        : undefined
    if (reference && !found.some((known) => known.bookId === reference.bookId))
      found.push(reference)
  }
  return found
}

const referenceOfBook = (
  book: Book,
  opinionOf: ReadonlyMap<string, SeriesOpinion>,
): SuggestionReference => {
  const own = tierOf(book.favorite, book.rating)
  const opinion = book.series ? opinionOf.get(book.series.id) : undefined
  return {
    bookId: book.id,
    ...(book.series ? { seriesId: book.series.id } : {}),
    title: book.title,
    ...(book.genre ? { genre: book.genre } : {}),
    rank:
      own || !opinion
        ? rankOf(book.favorite, book.rating, false)
        : rankOf(opinion.favorite, opinion.rating, true),
  }
}

/** A saga cited by name: its best-ranked volume, the first one on a tie. */
const referenceOfSaga = (
  volumes: readonly Book[],
  opinionOf: ReadonlyMap<string, SeriesOpinion>,
): SuggestionReference | undefined => {
  const ordered = [...volumes].sort(
    (left, right) => (left.series?.volume ?? 0) - (right.series?.volume ?? 0),
  )
  const first = ordered[0]
  if (!first?.series) return undefined
  const opinion = opinionOf.get(first.series.id)
  const best = [...volumes].sort((left, right) => scoreOf(right) - scoreOf(left))[0] ?? first
  const rank = opinion
    ? rankOf(opinion.favorite, opinion.rating, true)
    : rankOf(best.favorite, best.rating, false)
  const genre = ordered.find((volume) => volume.genre)?.genre
  return {
    bookId: first.id,
    seriesId: first.series.id,
    title: first.series.name,
    ...(genre ? { genre } : {}),
    rank,
  }
}

const scoreOf = (book: Pick<Book, 'favorite' | 'rating'>) =>
  (book.favorite ? 10 : 0) + (book.rating ?? 0)

const rankOf = (
  favorite: boolean | undefined,
  rating: StarRating | undefined,
  viaSeries: boolean,
): ReferenceRank => ({
  favorite: favorite === true,
  ...(rating !== undefined ? { rating } : {}),
  viaSeries,
})
