import SchemaBuilder from '@pothos/core'
import { GraphQLScalarType } from 'graphql'
import type { H3Event } from 'h3'
import type { TimeZone } from '~/domain/analytics/types'
import type { AudibleAsin } from '~/domain/audible/types'
import type {
  BookId,
  CoverUrl,
  Isbn13,
  PageCount,
  Publisher,
  ReadingNote,
  StarRating,
  Subgenre,
  Synopsis,
} from '~/domain/book/types'
import type { SeriesDescription, SeriesId, SeriesName, VolumeNumber } from '~/domain/series/types'
import type {
  AuthorName,
  BookTitle,
  Count,
  Eur,
  Percentage,
  PersonName,
  UserId,
  Year,
} from '~/domain/shared/types'
import type { SignedUrl } from '~/system/object-store/types'

/** What every resolver is handed. There is no loader map here, unlike Vinarium:
 *  a book carries its series name and volume number denormalized, so grouping a
 *  library into sections reads no catalogue document at all. The N+1 that loaders
 *  exist to solve is designed out rather than batched away. */
export type GraphQLContext = {
  event: H3Event
  userId: UserId
}

const DateTimeScalar = new GraphQLScalarType({
  name: 'DateTime',
  description:
    'A date and time serialized as an ISO 8601 string in UTC.\n\n' +
    'On output a JavaScript `Date` is rendered as an ISO string; on input an ISO ' +
    'string is parsed back into a `Date`. Used for record timestamps (`addedAt`, ' +
    '`startedAt`, `finishedAt`). Example: "2026-09-14T09:30:00.000Z".',
  serialize: (value: unknown) => (value instanceof Date ? value.toISOString() : value),
  parseValue: (value: unknown) => new Date(value as string),
})

export const builder = new SchemaBuilder<{
  Context: GraphQLContext
  DefaultFieldNullability: false
  Scalars: {
    DateTime: { Input: Date; Output: Date }
    UserId: { Input: UserId; Output: UserId }
    BookId: { Input: BookId; Output: BookId }
    BookTitle: { Input: BookTitle; Output: BookTitle }
    AuthorName: { Input: AuthorName; Output: AuthorName }
    PersonName: { Input: PersonName; Output: PersonName }
    Publisher: { Input: Publisher; Output: Publisher }
    Isbn13: { Input: Isbn13; Output: Isbn13 }
    Subgenre: { Input: Subgenre; Output: Subgenre }
    Synopsis: { Input: Synopsis; Output: Synopsis }
    PageCount: { Input: PageCount; Output: PageCount }
    StarRating: { Input: StarRating; Output: StarRating }
    ReadingNote: { Input: ReadingNote; Output: ReadingNote }
    SeriesId: { Input: SeriesId; Output: SeriesId }
    SeriesName: { Input: SeriesName; Output: SeriesName }
    SeriesDescription: { Input: SeriesDescription; Output: SeriesDescription }
    VolumeNumber: { Input: VolumeNumber; Output: VolumeNumber }
    Year: { Input: Year; Output: Year }
    Count: { Input: Count; Output: Count }
    Eur: { Input: Eur; Output: Eur }
    Percentage: { Input: Percentage; Output: Percentage }
    CoverUrl: { Input: CoverUrl; Output: CoverUrl | SignedUrl }
    TimeZone: { Input: TimeZone; Output: TimeZone }
    AudibleAsin: { Input: AudibleAsin; Output: AudibleAsin }
  }
}>({
  defaultFieldNullability: false,
})

builder.addScalarType('DateTime', DateTimeScalar)
builder.queryType({})
builder.mutationType({})
