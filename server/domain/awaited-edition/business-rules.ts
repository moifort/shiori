import { authorKeyOf } from '~/domain/author/primitives'
import type { AuthorKey } from '~/domain/author/types'
import { shelfKeyOf } from '~/domain/book/business-rules'
import type { Book, BookFormat, BookLanguage } from '~/domain/book/types'
import { lastDayOf, releaseFormatOf, WATCH_EVERY_MS } from '~/domain/discovery/business-rules'
import type { ReleaseFormat } from '~/domain/discovery/types'
import { isbn10Of } from '~/domain/scan/amazon-cover'
import { AMAZON_STORES } from '~/domain/shared/amazon-stores'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { AwaitedEditionId } from './primitives'
import type {
  AwaitedEdition,
  AwaitedEditionView,
  AwaitedSource,
  AwaitedState,
  EditionWatch,
  FoundEdition,
} from './types'

/** How many editions one reader may await: each one is a grounded call every
 *  two weeks. */
export const MAX_AWAITED = 100

/** How late an alert may still go out for an edition the morning pass missed:
 *  one already out when its two-weekly look finds it, a week of margin on top. */
const ALERT_GRACE_DAYS = 21

export const editionWatchKeyOf = (
  source: Pick<AwaitedSource, 'title' | 'authors'>,
  format: ReleaseFormat,
  language: BookLanguage,
): string => `${shelfKeyOf(source.title, source.authors[0])}--${format}--${language}`

export const awaitedIdOf = (userId: UserId, watchKey: string) =>
  AwaitedEditionId(`${userId}--${watchKey}`)

/** The formats a book's edition in the app's language may be awaited in. A
 *  book in another language may be awaited translated, and recorded; a printed
 *  book in the app's language only recorded — a book that names no language is
 *  taken to be in it, as everywhere else. Whether a store sells it already does
 *  not matter: one out when it is awaited is shown out, with its link. */
export const awaitableFormatsOf = (
  book: { language?: BookLanguage; format: BookFormat },
  appLanguage: Language,
): ReleaseFormat[] => {
  if ((book.language ?? appLanguage) !== appLanguage) return ['book', 'audiobook']
  return book.format === 'audiobook' ? [] : ['audiobook']
}

/** Where an edition stands on a day: out once its date is past, announced
 *  before, or with no date. A recording past its date is out even when
 *  Audible's catalogue did not confirm its ASIN: that catalogue misses French
 *  recordings that exist, and a date gone by drawn as still to come is worse
 *  than a link that searches the store. What only a confirmed recording earns
 *  is the alert — see `isConfirmed`. */
export const stateOf = (
  found: FoundEdition | undefined,
  _format: ReleaseFormat,
  today: string,
): AwaitedState => {
  if (!found) return 'unannounced'
  if (!found.date) return 'announced'
  const out = found.date.length === 10 ? found.date <= today : lastDayOf(found.date) < today
  return out ? 'available' : 'announced'
}

/** Whether a store confirmed the edition: always for print, whose date Amazon
 *  gives; for a recording, once Audible's catalogue answered for its ASIN. An
 *  edition out but not confirmed is still looked up, and never alerted. */
export const isConfirmed = (found: FoundEdition | undefined, format: ReleaseFormat): boolean =>
  format !== 'audiobook' || found?.asin !== undefined

export const viewOf = (
  awaited: AwaitedEdition,
  watch: EditionWatch | undefined,
  today: string,
): AwaitedEditionView => ({
  ...awaited,
  state: stateOf(watch?.found, awaited.format, today),
  ...(watch?.found ? { found: watch.found } : {}),
  watched: watch !== undefined,
})

/** Whether the reader now holds the edition awaited: a book of its format, in
 *  its language, that is the recording or the printed edition found, or bears
 *  its title and author. The source copy itself never ends the wait, being in
 *  another language. */
export const isHeld = (
  awaited: Pick<AwaitedEdition, 'format' | 'language' | 'source'>,
  found: FoundEdition | undefined,
  books: readonly Pick<
    Book,
    'format' | 'language' | 'title' | 'authors' | 'audibleAsin' | 'isbn13'
  >[],
): boolean => {
  if (!found) return false
  const key = shelfKeyOf(found.title, awaited.source.authors[0])
  return books.some(
    (book) =>
      releaseFormatOf(book.format) === awaited.format &&
      book.language === awaited.language &&
      ((found.asin !== undefined && book.audibleAsin === found.asin) ||
        (found.isbn13 !== undefined && book.isbn13 === found.isbn13) ||
        shelfKeyOf(book.title, book.authors[0]) === key),
  )
}

/** The watches the hourly pass looks up: the ones never looked up first, then
 *  the ones two weeks old, each once however many readers await it. An edition
 *  out and confirmed is not looked up again: there is nothing left to learn. A
 *  recording out that Audible never confirmed still is, for its ASIN. */
export const dueWatchesOf = (
  awaited: readonly AwaitedEdition[],
  watches: ReadonlyMap<string, EditionWatch>,
  now: Date,
  today: string,
): AwaitedEdition[] => {
  const due = new Map<string, AwaitedEdition>()
  for (const edition of awaited) {
    if (due.has(edition.watchKey)) continue
    const watch = watches.get(edition.watchKey)
    if (
      watch &&
      stateOf(watch.found, watch.format, today) === 'available' &&
      isConfirmed(watch.found, watch.format)
    )
      continue
    if (watch && now.getTime() - watch.checkedAt.getTime() < WATCH_EVERY_MS) continue
    due.set(edition.watchKey, edition)
  }
  return [...due.values()].sort(
    (left, right) =>
      Number(watches.has(left.watchKey)) - Number(watches.has(right.watchKey)) ||
      (watches.get(left.watchKey)?.checkedAt.getTime() ?? 0) -
        (watches.get(right.watchKey)?.checkedAt.getTime() ?? 0),
  )
}

/** Whether the alert for an edition out is due: never sent, confirmed by its
 *  store, and out on a known day in the last three weeks. An edition out
 *  earlier is passed over. */
export const alertIsDue = (view: AwaitedEditionView, today: string): boolean => {
  if (view.notifiedAt || view.state !== 'available') return false
  if (!isConfirmed(view.found, view.format)) return false
  const date = view.found?.date
  return date !== undefined && date.length === 10 && date >= dayMinus(today, ALERT_GRACE_DAYS)
}

/** The alert for an edition out, in the reader's language. */
export const alertOf = (
  { format, found, source }: AwaitedEditionView,
  language: Language,
): { title: string; body: string } => {
  const title = found?.title ?? source.title
  const author = source.authors[0]
  const audio = format === 'audiobook'
  if (language === 'fr')
    return {
      title: audio ? 'Sorti en audio' : 'Sorti en français',
      body: `« ${title} »${author ? ` de ${author}` : ''} est sorti${audio ? ' en livre audio' : ''}.`,
    }
  return {
    title: audio ? 'Out as an audiobook' : 'Out in English',
    body: `"${title}"${author ? ` by ${author}` : ''} is out${audio ? ' as an audiobook' : ''}.`,
  }
}

/** The order the shelf draws them in: the editions out first, the newest
 *  first; then the ones announced, the soonest first and the undated last;
 *  then the ones not announced, the latest awaited first. */
export const inShelfOrder = (views: readonly AwaitedEditionView[]): AwaitedEditionView[] => {
  const rank = { available: 0, announced: 1, unannounced: 2 } as const
  const dayOf = (view: AwaitedEditionView) => (view.found?.date ? lastDayOf(view.found.date) : '')
  return [...views].sort((left, right) => {
    if (left.state !== right.state) return rank[left.state] - rank[right.state]
    if (left.state === 'available') return dayOf(right).localeCompare(dayOf(left))
    if (left.state === 'announced') {
      const [l, r] = [dayOf(left), dayOf(right)]
      if (l !== r) return !l ? 1 : !r ? -1 : l.localeCompare(r)
    }
    return right.awaitedAt.getTime() - left.awaitedAt.getTime()
  })
}

/** The editions awaited in one format that are announced or out, under the
 *  key of each of their authors, in the shelf's order — what an author's page
 *  and their row on Découvrir's Authors shelf add to the works the web found.
 *  One the reader holds now is left out: the next read of the list ends it. */
export const awaitedByAuthorOf = (
  views: readonly AwaitedEditionView[],
  format: ReleaseFormat,
  books: readonly Pick<
    Book,
    'format' | 'language' | 'title' | 'authors' | 'audibleAsin' | 'isbn13'
  >[],
): Map<AuthorKey, AwaitedEditionView[]> => {
  const byAuthor = new Map<AuthorKey, AwaitedEditionView[]>()
  const shown = views.filter(
    (view) =>
      view.format === format && view.state !== 'unannounced' && !isHeld(view, view.found, books),
  )
  for (const view of inShelfOrder(shown))
    for (const key of new Set(view.source.authors.map(authorKeyOf)))
      byAuthor.set(key, [...(byAuthor.get(key) ?? []), view])
  return byAuthor
}

/** The Audible store that sells the recordings of each language, for a reader
 *  with no Audible account to take the store from. */
const AUDIBLE_DOMAINS: Partial<Record<BookLanguage, string>> = {
  fr: 'audible.fr',
  en: 'audible.com',
  de: 'audible.de',
  es: 'audible.es',
  it: 'audible.it',
  ja: 'audible.co.jp',
}

/** Where to get an edition found, in its language's store: a recording's page
 *  on Audible once its ASIN is confirmed, else a search for its title and
 *  author on that store, out or still announced; a printed edition's page on
 *  Amazon, reached by the ISBN-10 Amazon files it under or else searched by its
 *  ISBN, nothing without one. */
export const storeUrlOf = (
  format: ReleaseFormat,
  language: BookLanguage,
  found: Pick<FoundEdition, 'asin' | 'isbn13'> & { title?: string },
  author?: string,
): string | undefined => {
  if (format === 'audiobook') {
    const domain = AUDIBLE_DOMAINS[language]
    if (!domain) return undefined
    if (found.asin) return `https://www.${domain}/pd/${found.asin}`
    const keywords = [found.title, author].filter(Boolean).join(' ')
    return `https://www.${domain}/search?keywords=${encodeURIComponent(keywords)}`
  }
  const store = AMAZON_STORES[language]
  if (!found.isbn13 || !store) return undefined
  const isbn10 = isbn10Of(found.isbn13)
  return isbn10 ? `https://www.${store}/dp/${isbn10}` : `https://www.${store}/s?k=${found.isbn13}`
}

const dayMinus = (today: string, days: number): string => {
  const [year, month, day] = today.split('-').map(Number)
  return new Date(Date.UTC(year, month - 1, day) - days * 86_400_000).toISOString().slice(0, 10)
}
