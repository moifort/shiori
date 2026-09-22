import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  BookFormat,
  BookId as BookIdType,
  BookLanguage,
  CoverUrl as CoverUrlType,
  Genre,
  Isbn13 as Isbn13Type,
  ListeningMinutes as ListeningMinutesType,
  NarratorName as NarratorNameType,
  PageCount as PageCountType,
  Publisher as PublisherType,
  ReadingNote as ReadingNoteType,
  ReadingStatus,
  RecommendationComment as RecommendationCommentType,
  StarRating as StarRatingType,
  Subgenre as SubgenreType,
  Synopsis as SynopsisType,
} from '~/domain/book/types'
import { BOOK_FORMATS, BOOK_LANGUAGES, GENRES, READING_STATUSES } from '~/domain/book/types'

export { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'

export const BookId = (value: unknown) => {
  const v = z.string().min(1).max(200).parse(value)
  return make<BookIdType>()(v)
}

export const Publisher = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<PublisherType>()(v)
}

/** The words a subgenre keeps in lower case unless it starts with them, in the
 *  two languages its labels arrive in. */
const MINOR_WORDS = new Set([
  'à',
  'au',
  'aux',
  'de',
  'des',
  'du',
  'en',
  'et',
  'la',
  'le',
  'les',
  'ou',
  'par',
  'pour',
  'sur',
  'un',
  'une',
  'a',
  'an',
  'and',
  'for',
  'in',
  'of',
  'on',
  'or',
  'the',
  'to',
  'with',
])

const capitalized = (word: string): string => word.charAt(0).toLocaleUpperCase('fr') + word.slice(1)

/** One word of a subgenre as it is shelved: its first letter raised, every
 *  other letter left as typed — "LitRPG" stays "LitRPG", never "Litrpg". A minor
 *  word inside the label is lowered, and an elided article keeps its
 *  apostrophe lowered with the word after it raised: "Roman d'Aventure". */
const shelvedWord = (word: string, first: boolean): string => {
  const lowered = word.toLocaleLowerCase('fr')
  if (!first && MINOR_WORDS.has(lowered)) return lowered
  const elision = /^([dlDL])(['’])(.+)$/u.exec(word)
  if (elision) {
    const [, article, apostrophe, rest] = elision
    return `${first ? article.toUpperCase() : article.toLowerCase()}${apostrophe}${capitalized(rest)}`
  }
  return capitalized(word)
}

/** A subgenre in title case, so the scan, the imports and the form converge on
 *  one spelling of each: "dark fantasy", "Dark fantasy" and "Dark Fantasy" were
 *  three entries in the autocompletion. */
export const Subgenre = (value: unknown) => {
  const v = z
    .string()
    .trim()
    .min(1)
    .max(100)
    .transform((label) =>
      label
        .split(/\s+/u)
        .map((word, index) => shelvedWord(word, index === 0))
        .join(' '),
    )
    .parse(value)
  return make<SubgenreType>()(v)
}

/** A book carries at most three subgenres: past that they stop refining the
 *  genre and start restating the synopsis. */
export const MAX_SUBGENRES = 3

export const NarratorName = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<NarratorNameType>()(v)
}

/** A full-cast recording can credit dozens of voices; the ones a reader wants
 *  named are the leads. Past five the line stops identifying the recording and
 *  starts being a cast list. */
export const MAX_NARRATORS = 5

export const Synopsis = (value: unknown) => {
  const v = z.string().trim().min(1).max(4000).parse(value)
  return make<SynopsisType>()(v)
}

// A book past 20,000 pages is a grounding error, not a book. Zero is refused
// rather than stored: an unknown page count is an absent field, not a zero.
export const PageCount = (value: unknown) => {
  const v = z
    .preprocess((v) => (typeof v === 'string' ? Number(v) : v), z.number().int().min(1).max(20000))
    .parse(value)
  return make<PageCountType>()(v)
}

// A recording past a thousand hours is a parsing accident, not an audiobook.
// Zero is refused rather than stored: an unknown running time is an absent field.
export const ListeningMinutes = (value: unknown) => {
  const v = z
    .preprocess((v) => (typeof v === 'string' ? Number(v) : v), z.number().int().min(1).max(60000))
    .parse(value)
  return make<ListeningMinutesType>()(v)
}

// Validated on its check digit, not just its shape. The model invents ISBNs that
// look right and are not, and a wrong ISBN silently poisons any later lookup, so
// a failing check digit is refused at the door.
export const Isbn13 = (value: unknown) => {
  const v = z
    .string()
    .transform((raw) => raw.replace(/[\s-]/g, ''))
    .refine((digits) => /^\d{13}$/.test(digits), 'ISBN-13 must be 13 digits')
    .refine(hasValidIsbn13CheckDigit, 'ISBN-13 check digit does not match')
    .parse(value)
  return make<Isbn13Type>()(v)
}

const hasValidIsbn13CheckDigit = (digits: string): boolean => {
  const sum = [...digits]
    .slice(0, 12)
    .reduce((total, digit, index) => total + Number(digit) * (index % 2 === 0 ? 1 : 3), 0)
  return (10 - (sum % 10)) % 10 === Number(digits[12])
}

// HTTPS only: App Transport Security blocks a plain HTTP image, so an `http://`
// cover would be stored and then silently never drawn.
export const CoverUrl = (value: unknown) => {
  const v = z
    .string()
    .url()
    .refine((url) => url.startsWith('https://'), 'cover URL must be HTTPS')
    .parse(value)
  return make<CoverUrlType>()(v)
}

export const StarRating = (value: unknown) => {
  const v = z
    .preprocess((v) => (typeof v === 'string' ? Number(v) : v), z.number().int().min(1).max(5))
    .parse(value)
  return make<StarRatingType>()(v)
}

export const ReadingNote = (value: unknown) => {
  const v = z.string().trim().min(1).max(10000).parse(value)
  return make<ReadingNoteType>()(v)
}

export const RecommendationComment = (value: unknown) => {
  const v = z.string().trim().min(1).max(2000).parse(value)
  return make<RecommendationCommentType>()(v)
}

export const ReadingStatusValue = (value: unknown): ReadingStatus =>
  z.enum(READING_STATUSES).parse(value)

export const GenreValue = (value: unknown): Genre => z.enum(GENRES).parse(value)

export const BookFormatValue = (value: unknown): BookFormat => z.enum(BOOK_FORMATS).parse(value)

export const BookLanguageValue = (value: unknown): BookLanguage =>
  z.enum(BOOK_LANGUAGES).parse(value)
