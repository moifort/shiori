import { GraphQLError } from 'graphql'
import { ZodError } from 'zod'
import { TimeZone } from '~/domain/analytics/primitives'
import { AudibleAsin } from '~/domain/audible/primitives'
import {
  BookId,
  CoverUrl,
  Isbn13,
  ListeningMinutes,
  NarratorName,
  PageCount,
  Publisher,
  ReadingNote,
  RecommendationComment,
  StarRating,
  Subgenre,
  Synopsis,
} from '~/domain/book/primitives'
import { DeviceToken } from '~/domain/notification/primitives'
import { SeriesDescription, SeriesId, SeriesName, VolumeNumber } from '~/domain/series/primitives'
import {
  AuthorName,
  BookTitle,
  Count,
  Eur,
  Percentage,
  PersonName,
  UserId,
  Year,
} from '~/domain/shared/primitives'
import { builder } from './builder'

// A brand's Zod constructor is the single definition of what the value may be, so
// the scalar reuses it rather than restating the rule. A rejection becomes a
// BAD_USER_INPUT the client can show, not a 500.
const validatedParse =
  <T>(name: string, parse: (value: unknown) => T) =>
  (value: unknown): T => {
    try {
      return parse(value)
    } catch (error) {
      const message =
        error instanceof ZodError
          ? error.issues.map(({ message }) => message).join(', ')
          : `Invalid ${name}`
      throw new GraphQLError(`Invalid value for ${name}: ${message}`, {
        extensions: { code: 'BAD_USER_INPUT' },
      })
    }
  }

builder.scalarType('UserId', {
  description:
    'A Firebase Auth user identifier, carried as an opaque non-empty string.\n\n' +
    'Every book is owned by a `UserId`; the viewer identity is derived from the ' +
    'request Bearer token, so this is rarely passed as an input. ' +
    'Example: "KyTjMU39NBhfakGxExfqLmC5OYU2".',
  serialize: (value) => value as string,
  parseValue: validatedParse('UserId', UserId),
})

builder.scalarType('BookId', {
  description:
    'Identifier of one book in one reader library, as a UUID v4.\n\n' +
    'Scoped to its owner: the same novel catalogued by two readers has two ' +
    'unrelated ids. Example: "f9b1c2d0-4e3a-4c21-9f77-1a2b3c4d5e6f".',
  serialize: (value) => value as string,
  parseValue: validatedParse('BookId', BookId),
})

builder.scalarType('BookTitle', {
  description:
    'The title of a book, 1 to 300 characters.\n\n' +
    'Bounded because it often comes from a model reading a cover: a 500-character ' +
    '"title" is a misread blurb. Example: "The Name of the Wind".',
  serialize: (value) => value as string,
  parseValue: validatedParse('BookTitle', BookTitle),
})

builder.scalarType('AuthorName', {
  description: 'An author name as printed, 1 to 200 characters. Example: "Patrick Rothfuss".',
  serialize: (value) => value as string,
  parseValue: validatedParse('AuthorName', AuthorName),
})

builder.scalarType('PersonName', {
  description:
    'A person the reader knows, by name, 1 to 200 characters: the reader themselves, ' +
    'asked once during onboarding so the app can address them, or the friend who ' +
    'recommended a book, as the contact picker spelled it. Distinct from ' +
    '`AuthorName`, which names someone who wrote a book. Example: "Thibaut".',
  serialize: (value) => value as string,
  parseValue: validatedParse('PersonName', PersonName),
})

builder.scalarType('Publisher', {
  description: 'The publisher of this edition, 1 to 200 characters. Example: "DAW Books".',
  serialize: (value) => value as string,
  parseValue: validatedParse('Publisher', Publisher),
})

builder.scalarType('Isbn13', {
  description:
    'A 13-digit ISBN, hyphens and spaces removed, validated on its check digit.\n\n' +
    'The check digit is enforced rather than assumed: models invent ISBNs that ' +
    'look right, and a wrong one silently poisons every later lookup. ' +
    'Example: "9780756404741".',
  serialize: (value) => value as string,
  parseValue: validatedParse('Isbn13', Isbn13),
})

builder.scalarType('NarratorName', {
  description:
    'Who reads an audiobook aloud, 1 to 200 characters. Not an AuthorName: a ' +
    'narrator is not the author of what they read. Example: "Bernard Gabay".',
  serialize: (value) => value as string,
  parseValue: validatedParse('NarratorName', NarratorName),
})

builder.scalarType('Subgenre', {
  description:
    'One free label refining the genre, 1 to 100 characters, never translated: sent ' +
    'in the language of `Accept-Language`, served as it was written. Example: "Dark fantasy".',
  serialize: (value) => value as string,
  parseValue: validatedParse('Subgenre', Subgenre),
})

builder.scalarType('Synopsis', {
  description: 'The book summary, 1 to 4000 characters, in the caller language.',
  serialize: (value) => value as string,
  parseValue: validatedParse('Synopsis', Synopsis),
})

builder.scalarType('PageCount', {
  description:
    'Page count of this edition, 1 to 20000. Absent when unknown — never zero, ' +
    'which would read as a real count of nothing. Example: 662.',
  serialize: (value) => value as number,
  parseValue: validatedParse('PageCount', PageCount),
})

builder.scalarType('ListeningMinutes', {
  description:
    'An audiobook running time in whole minutes, 1 to 60000. Absent when unknown. ' +
    'Example: 870 for 14 h 30.',
  serialize: (value) => value as number,
  parseValue: validatedParse('ListeningMinutes', ListeningMinutes),
})

builder.scalarType('StarRating', {
  description:
    'A reader rating, 1 to 5 whole stars.\n\n' +
    'Whole stars only: half stars double the value space without adding ' +
    'discernment. Setting a rating also marks the book as read. Example: 4.',
  serialize: (value) => value as number,
  parseValue: validatedParse('StarRating', StarRating),
})

builder.scalarType('ReadingNote', {
  description:
    'The reader own note on a book, 1 to 10000 characters. Clearing it deletes ' +
    'it rather than storing an empty string.',
  serialize: (value) => value as string,
  parseValue: validatedParse('ReadingNote', ReadingNote),
})

builder.scalarType('RecommendationComment', {
  description:
    'What the friend who recommended a book said of it, 1 to 2000 characters. ' +
    'Example: "The best heist story you will ever read."',
  serialize: (value) => value as string,
  parseValue: validatedParse('RecommendationComment', RecommendationComment),
})

builder.scalarType('SeriesId', {
  description:
    'Identifier of a series in the shared catalogue, derived from its name and ' +
    'author rather than random.\n\n' +
    'Deterministic on purpose: two readers scanning volumes of the same saga must ' +
    'reach the same catalogue document, so it is paid for once. Diacritics are ' +
    'folded and a leading article dropped. Example: "wheel-of-time--robert-jordan".',
  serialize: (value) => value as string,
  parseValue: validatedParse('SeriesId', SeriesId),
})

builder.scalarType('SeriesName', {
  description: 'The name of a series, 1 to 200 characters. Example: "The Wheel of Time".',
  serialize: (value) => value as string,
  parseValue: validatedParse('SeriesName', SeriesName),
})

builder.scalarType('SeriesDescription', {
  description: 'A short description of the saga, 1 to 2000 characters, in the caller language.',
  serialize: (value) => value as string,
  parseValue: validatedParse('SeriesDescription', SeriesDescription),
})

builder.scalarType('VolumeNumber', {
  description:
    'Position of a volume along the spine of its series, 1 to 200.\n\n' +
    'Absent on anything that is not a numbered main volume: a spin-off or a ' +
    'companion has no place in the numbering. Example: 3.',
  serialize: (value) => value as number,
  parseValue: validatedParse('VolumeNumber', VolumeNumber),
})

builder.scalarType('Year', {
  description:
    'A four-digit publication year, from 1450 to ten years out.\n\n' +
    'The upper bound leaves room for an announced but unpublished volume, which ' +
    'the series catalogue keeps on purpose. Example: 2007.',
  serialize: (value) => value as number,
  parseValue: validatedParse('Year', Year),
})

builder.scalarType('Count', {
  description: 'A non-negative whole number of things. Example: 12.',
  serialize: (value) => value as number,
  parseValue: validatedParse('Count', (value) => Count(Number(value))),
})

builder.scalarType('Eur', {
  description: 'An amount in euros, never negative. Example: 2.99.',
  serialize: (value) => value as number,
  parseValue: validatedParse('Eur', Eur),
})

builder.scalarType('Percentage', {
  description: 'A percentage from 0 to 100. Example: 42.5.',
  serialize: (value) => value as number,
  parseValue: validatedParse('Percentage', Percentage),
})

builder.scalarType('CoverUrl', {
  description:
    'An HTTPS URL to draw a book cover from.\n\n' +
    'Either the reader own photo, signed and expiring after an hour, or the ' +
    'publisher cover found by ISBN. Neither is guaranteed to load: draw the ' +
    'placeholder when the image fails, and refetch the book rather than storing ' +
    'the URL client-side.',
  serialize: (value) => value as string,
  parseValue: validatedParse('CoverUrl', CoverUrl),
})

builder.scalarType('TimeZone', {
  description:
    'An IANA time zone identifier known to the server, such as "Europe/Paris". ' +
    'Reading statistics count days, months and years in it.',
  serialize: (value) => value as string,
  parseValue: validatedParse('TimeZone', TimeZone),
})

builder.scalarType('AudibleAsin', {
  description:
    "Amazon's identifier for one audiobook: ten upper-case alphanumeric " +
    'characters.\n\n' +
    'Handed out by `audibleLibrary` and passed straight back to ' +
    '`importAudibleBooks` to say which titles to catalogue. Example: "B002V1OF70".',
  serialize: (value) => value as string,
  parseValue: validatedParse('AudibleAsin', AudibleAsin),
})

builder.scalarType('DeviceToken', {
  description:
    'The token APNs hands a device for this app, in hexadecimal, as the app ' +
    'receives it on registering for remote notifications.',
  serialize: (value) => value as string,
  parseValue: validatedParse('DeviceToken', DeviceToken),
})
