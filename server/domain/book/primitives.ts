import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  BookFormat,
  BookId as BookIdType,
  Genre as GenreType,
  Isbn13 as Isbn13Type,
  PageCount as PageCountType,
  Publisher as PublisherType,
  ReadingNote as ReadingNoteType,
  ReadingStatus,
  StarRating as StarRatingType,
  Synopsis as SynopsisType,
} from '~/domain/book/types'
import { BOOK_FORMATS, READING_STATUSES } from '~/domain/book/types'

export { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'

export const BookId = (value: unknown) => {
  const v = z.string().min(1).max(200).parse(value)
  return make<BookIdType>()(v)
}

export const Publisher = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<PublisherType>()(v)
}

export const Genre = (value: unknown) => {
  const v = z.string().trim().min(1).max(100).parse(value)
  return make<GenreType>()(v)
}

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

export const ReadingStatusValue = (value: unknown): ReadingStatus =>
  z.enum(READING_STATUSES).parse(value)

export const BookFormatValue = (value: unknown): BookFormat => z.enum(BOOK_FORMATS).parse(value)
