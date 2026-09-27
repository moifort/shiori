import { AudibleAsin } from '~/domain/audible/primitives'
import { Isbn13 } from '~/domain/book/primitives'
import type { BookLanguage } from '~/domain/book/types'
import { ReleaseDate, SeriesName, VolumeNumber } from '~/domain/series/primitives'
import type { ReleaseDate as ReleaseDateType } from '~/domain/series/types'
import { BookTitle } from '~/domain/shared/primitives'
import { optionally } from '~/utils/input'
import { slugify } from '~/utils/slug'
import type { VolumeOutput, WorkOutput } from './schemas'
import type { FoundVolume, FoundWork } from './types'

/** Every volume of the model's answer, one per number — the first listed wins —
 *  or nothing without a title or a number. Every other field is dropped on its
 *  own when it does not validate: a hallucinated ISBN must not cost the reader
 *  a real volume. */
export const volumesFrom = (raw: readonly VolumeOutput[]): FoundVolume[] => {
  const volumes = new Map<number, FoundVolume>()
  for (const entry of raw) {
    const number = optionally(entry.number, VolumeNumber)
    const title = optionally(entry.title, BookTitle)
    if (number === undefined || !title || volumes.has(number)) continue
    volumes.set(number, {
      number,
      title,
      date: optionally(entry.date, ReleaseDate),
      isbn13: optionally(entry.isbn13, Isbn13),
      asin: optionally(entry.asin, AudibleAsin),
    })
  }
  return [...volumes.values()].sort((left, right) => left.number - right.number)
}

/** Every work of the model's answer, one per folded title — the first listed
 *  wins — or nothing without a title. Every other field is dropped on its own
 *  when it does not validate, as `volumesFrom` does. */
export const worksFrom = (raw: readonly WorkOutput[]): FoundWork[] => {
  const works = new Map<string, FoundWork>()
  for (const entry of raw) {
    const title = optionally(entry.title, BookTitle)
    if (!title || works.has(slugify(title))) continue
    const seriesName = optionally(entry.series, SeriesName)
    const volume = optionally(entry.volume, VolumeNumber)
    works.set(slugify(title), {
      title,
      date: optionally(entry.date, ReleaseDate),
      isbn13: optionally(entry.isbn13, Isbn13),
      asin: optionally(entry.asin, AudibleAsin),
      ...(seriesName ? { seriesName } : {}),
      ...(volume !== undefined ? { volume } : {}),
    })
  }
  return [...works.values()]
}

/** Every month name an Amazon store writes a date with, lower-cased, to its
 *  number. */
const MONTHS: Record<string, number> = Object.fromEntries(
  [
    [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ],
    [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ],
    [
      'januar',
      'februar',
      'märz',
      'april',
      'mai',
      'juni',
      'juli',
      'august',
      'september',
      'oktober',
      'november',
      'dezember',
    ],
    [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ],
    [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ],
    [
      'januari',
      'februari',
      'maart',
      'april',
      'mei',
      'juni',
      'juli',
      'augustus',
      'september',
      'oktober',
      'november',
      'december',
    ],
  ].flatMap((names) => names.map((name, index) => [name, index + 1])),
)

/** A date as an Amazon store writes it — "26 août 2021", "December 30, 2025",
 *  "1. März 2024", "2024/3/1" — as a day, or undefined. */
export const amazonDateOf = (text: string): ReleaseDateType | undefined => {
  const cleaned = text.trim().toLowerCase().replace(/[.,]/g, ' ').replace(/\s+/g, ' ')
  const numeric = cleaned.match(/^(\d{4})\/(\d{1,2})\/(\d{1,2})$/)
  const dayFirst = cleaned.match(/^(\d{1,2}) (?:de )?(\p{L}+) (?:de )?(\d{4})$/u)
  const monthFirst = cleaned.match(/^(\p{L}+) (\d{1,2}) (\d{4})$/u)
  const [year, month, day] = numeric
    ? [numeric[1], Number(numeric[2]), numeric[3]]
    : dayFirst
      ? [dayFirst[3], MONTHS[dayFirst[2]], dayFirst[1]]
      : monthFirst
        ? [monthFirst[3], MONTHS[monthFirst[1]], monthFirst[2]]
        : []
  if (!year || !month || !day) return undefined
  return optionally(
    `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`,
    ReleaseDate,
  )
}

/** How each Amazon store names the language of a book, lower-cased. */
const AMAZON_LANGUAGE_NAMES: Partial<Record<BookLanguage, string[]>> = {
  fr: ['français', 'french', 'französisch', 'francés', 'francese'],
  en: ['english', 'anglais', 'englisch', 'inglés', 'inglese', 'engels'],
  de: ['deutsch', 'german', 'allemand', 'alemán', 'tedesco', 'duits'],
  es: ['español', 'spanish', 'espagnol', 'spanisch', 'spagnolo', 'spaans'],
  it: ['italiano', 'italian', 'italien', 'italienisch', 'italiaans'],
  nl: ['nederlands', 'dutch', 'néerlandais', 'niederländisch', 'neerlandés', 'olandese'],
}

/** The value Amazon's book details carousel shows beside one of its icons. */
const carouselValue = (html: string, icon: string): string | undefined =>
  html.match(new RegExp(`rpi-icon ${icon}".*?rpi-attribute-value[^>]*>\\s*<span>([^<]+)`, 's'))?.[1]

/** What an Amazon book page says of the edition: its release day, or `unknown`
 *  when the page is of a book in another language — the ISBN was not that
 *  edition's — or `unreadable` when the page holds no book details at all,
 *  which is what a captcha looks like. */
export const amazonEditionFrom = (
  html: string,
  language: BookLanguage,
): { releaseDate?: ReleaseDateType } | 'unknown' | 'unreadable' => {
  const date = carouselValue(html, 'book_details-publication_date')
  const shown = carouselValue(html, 'language')?.trim().toLowerCase()
  if (!date && !shown) return 'unreadable'
  const names = AMAZON_LANGUAGE_NAMES[language]
  if (shown && names && !names.includes(shown)) return 'unknown'
  const releaseDate = date ? amazonDateOf(date) : undefined
  return releaseDate ? { releaseDate } : {}
}
