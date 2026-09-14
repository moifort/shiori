import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  AuthorName as AuthorNameType,
  BookTitle as BookTitleType,
  Count as CountType,
  Eur as EurType,
  Month as MonthType,
  Percentage as PercentageType,
  PersonName as PersonNameType,
  UserId as UserIdType,
  Year as YearType,
} from '~/domain/shared/types'

export const UserId = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<UserIdType>()(v)
}

export const Eur = (value: unknown) => {
  const v = z
    .preprocess((v) => (typeof v === 'string' ? Number(v) : v), z.number().nonnegative())
    .parse(value)
  return make<EurType>()(v)
}

// The lower bound is the year movable type reached Europe: anything below it is a
// grounding hallucination rather than a publication year. The upper bound leaves
// room for an announced but unpublished volume, which the series catalogue needs.
export const Year = (value: unknown) => {
  const v = z
    .preprocess(
      (v) => (typeof v === 'string' ? Number(v) : v),
      z
        .number()
        .int()
        .min(1450)
        .max(new Date().getUTCFullYear() + 10),
    )
    .parse(value)
  return make<YearType>()(v)
}

export const Month = (value: unknown) => {
  const v = z
    .string()
    .regex(/^\d{4}-\d{2}$/)
    .parse(value)
  return make<MonthType>()(v)
}

export const Count = (value: number) => make<CountType>()(value)

export const Percentage = (value: unknown) => {
  const v = z
    .preprocess((v) => (typeof v === 'string' ? Number(v) : v), z.number().min(0).max(100))
    .parse(value)
  return make<PercentageType>()(v)
}

// Titles and author names come from an AI reading a cover, so they are bounded
// rather than trusted: a 500-character "title" is a misread blurb, not a title.
export const BookTitle = (value: unknown) => {
  const v = z.string().trim().min(1).max(300).parse(value)
  return make<BookTitleType>()(v)
}

export const AuthorName = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<AuthorNameType>()(v)
}

export const PersonName = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<PersonNameType>()(v)
}
