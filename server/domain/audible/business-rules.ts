import type { AudibleItem } from 'audible-api-ts'
import { AudibleAsin } from '~/domain/audible/primitives'
import type { ImportableBook } from '~/domain/audible/types'
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
import type { Book, ReadingStatus } from '~/domain/book/types'
import { SeriesName, seriesKeyOf, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { AuthorName as AuthorNameValue } from '~/domain/shared/types'
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

  const authors = (item.authors ?? [])
    .map((author) => optionally(author, AuthorName))
    .filter(isPresent)
  const status = statusOf(item)

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
    // Audible spells the language out ("french", "english"), and files a handful
    // of titles under a language nobody expected. Unknown ones are dropped: a
    // guess here would split a saga's shelves on a value nothing established.
    language: optionally(languageCodeOf(item.language), BookLanguageValue),
    coverUrl: optionally(largestCoverOf(item), CoverUrl),
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
 *  No `genre` either. Audible's category ladders are localized per marketplace,
 *  so mapping them onto the closed genre list would need ten translations of it
 *  and would still drift; the reader picks a genre on the book screen, as they do
 *  for a book typed by hand.
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
  series: importable.series,
  status: importable.status,
  language: importable.language,
  finishedAt: importable.finishedAt,
  durationMinutes: importable.durationMinutes,
  narrators: importable.narrators,
})

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
 *  identifier stored on the book: an import writes an ordinary book, and matching
 *  on the text means a title the reader scanned from the printed edition is
 *  recognized too — which an ASIN kept on the record would never have caught. */
export const shelfKeyOf = (title: string, author: string | undefined): string =>
  `${slugify(title)}--${slugify(author ?? '')}`

export const shelfKeysOf = (books: readonly Book[]): Set<string> =>
  new Set(books.map((book) => shelfKeyOf(book.title, book.authors[0])))
