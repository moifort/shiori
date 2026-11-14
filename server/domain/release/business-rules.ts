import type { EditionWatch } from '~/domain/awaited-edition/types'
import { shelfKeyOf } from '~/domain/book/copies'
import type { BookLanguage } from '~/domain/book/types'
import { lastDayOf } from '~/domain/discovery/business-rules'
import type { ReleaseFormat, ReleaseSeed } from '~/domain/discovery/types'
import type { ReleaseDate } from '~/domain/series/types'
import type { Language } from '~/domain/shared/language'
import { slugify } from '~/utils/slug'
import type { KeptDescription, Release, ReleaseShown, ReleaseView } from './types'

/** How long a description made before the book was out serves before it is
 *  asked again: an announced book is described thinly, and grows a summary
 *  once it is out. One made after it came out is kept for good. */
export const DESCRIPTION_KEPT_DAYS = 60

/** The key a release is kept under: the book it is looked for from, by its
 *  title and first author, the format and the language of the edition. Every
 *  reader, every list and every page that shows the same edition converge on
 *  it. */
export const releaseKeyOf = (
  title: string,
  author: string | undefined,
  format: ReleaseFormat,
  language: BookLanguage,
): string => `${shelfKeyOf(title, author)}--${format}--${language}`

/** The release as a watch, when the web was ever searched for it. */
export const watchOf = (release: Release | undefined): EditionWatch | undefined =>
  release?.checkedAt ? (release as EditionWatch) : undefined

/** Which shown book a description describes: the original, in its language,
 *  while nobody announced the edition; the edition, by its own title, once
 *  found. A description of the other one no longer serves. */
export const describedFromOf = (seed: Pick<ReleaseSeed, 'title' | 'language'>): string =>
  `${slugify(seed.title)}~${seed.language ?? '-'}`

/** The description kept in the app's language, if it describes the book the
 *  seed shows — stale or not. */
export const keptDescriptionOf = (
  release: Pick<Release, 'descriptions'> | undefined,
  seed: Pick<ReleaseSeed, 'title' | 'language'>,
  appLanguage: Language,
): KeptDescription | undefined => {
  const kept = release?.descriptions?.[appLanguage]
  return kept && kept.describedFrom === describedFromOf(seed) ? kept : undefined
}

/** Whether a kept description still serves as it is: for good once it was
 *  made after the book came out, since nothing about a book out changes; for
 *  `DESCRIPTION_KEPT_DAYS` otherwise, so that an announced book is described
 *  again once it is out. A date known only to the month or the year counts
 *  from its last day. */
export const isDescriptionFresh = (
  kept: Pick<KeptDescription, 'describedAt'>,
  now: Date,
  releasedOn?: ReleaseDate,
): boolean =>
  (releasedOn !== undefined &&
    kept.describedAt.toISOString().slice(0, 10) > lastDayOf(releasedOn)) ||
  now.getTime() - kept.describedAt.getTime() < DESCRIPTION_KEPT_DAYS * 86_400_000

/** The release as one reader is shown it, in a list and on its page alike: the
 *  edition found first, then what the app knew of the book, then what its page
 *  described. The book stays the one shown — its title, format, edition, saga
 *  and date — whatever the description says. A recording has no pages, and
 *  the ISBN of the print is not its own. */
export const releaseViewOf = (
  shown: ReleaseShown,
  release: Pick<Release, 'descriptions'> | undefined,
  appLanguage: Language,
  now: Date,
): ReleaseView => {
  const { seed, found } = shown
  const kept = keptDescriptionOf(release, seed, appLanguage)
  const described = kept?.description
  const book = described?.book
  const heard = shown.releaseFormat === 'audiobook'
  const coverUrl = found?.coverUrl ?? seed.coverUrl
  const date = found?.date ?? seed.releasedOn
  const isbn13 = heard ? undefined : (found?.isbn13 ?? seed.isbn13 ?? book?.isbn13)
  const series =
    shown.series ??
    (book?.series ? { name: book.series.name, volume: book.series.volume } : undefined)
  return {
    key: shown.key,
    title: seed.title,
    originalTitle: shown.originalTitle,
    authors: seed.authors.length > 0 ? seed.authors : (book?.authors ?? []),
    format: seed.format,
    releaseFormat: shown.releaseFormat,
    language: seed.language ?? shown.language,
    editionLanguage: shown.language,
    originalLanguage: shown.originalLanguage,
    state: shown.state,
    watched: shown.watched,
    ...(date ? { date } : {}),
    ...(isbn13 ? { isbn13 } : {}),
    ...(found?.asin ? { asin: found.asin } : {}),
    ...(coverUrl ? { coverUrl } : {}),
    ...(shown.coverPath ? { coverPath: shown.coverPath } : {}),
    ...(book?.coverUrl ? { describedCoverUrl: book.coverUrl } : {}),
    ...(shown.fallbackCoverUrl ? { fallbackCoverUrl: shown.fallbackCoverUrl } : {}),
    ...(series ? { series } : {}),
    ...(book?.publisher ? { publisher: book.publisher } : {}),
    ...(book?.firstPublishedIn ? { firstPublishedIn: book.firstPublishedIn } : {}),
    ...(book?.synopsis ? { synopsis: book.synopsis } : {}),
    ...(book?.genre ? { genre: book.genre } : {}),
    subgenres: book?.subgenres ?? [],
    ...(!heard && book?.pageCount ? { pageCount: book.pageCount } : {}),
    narrators: described?.narrators ?? [],
    ...(described?.durationMinutes ? { durationMinutes: described.durationMinutes } : {}),
    described: kept !== undefined && isDescriptionFresh(kept, now, date),
    ...(found ? { found } : {}),
  }
}
