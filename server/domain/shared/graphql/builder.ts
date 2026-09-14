import SchemaBuilder from '@pothos/core'
import { GraphQLScalarType } from 'graphql'
import type { H3Event } from 'h3'
import type {
  AttachmentId,
  ByteSize,
  ContentType,
  FileName,
  SignedUrl,
} from '~/domain/attachment/types'
import type {
  Appellation,
  BeverageId,
  BeverageName,
  Celsius,
  Classification,
  Cuvee,
  GrapeVariety,
  Notes,
  Producer,
} from '~/domain/beverage/types'
import type { HouseholdId } from '~/domain/household/types'
import type {
  Country,
  Eur,
  Latitude,
  Longitude,
  Percentage,
  PersonName,
  PlaceName,
  Region,
  UserId,
  Year,
} from '~/domain/shared/types'
import type { Rating } from '~/domain/tasting/types'
import type { BeverageSatelliteLoaders } from './loaders'

export type GraphQLContext = {
  event: H3Event
  userId: UserId
  loaders: BeverageSatelliteLoaders
}

const DateTimeScalar = new GraphQLScalarType({
  name: 'DateTime',
  description:
    'A date and time serialized as an ISO 8601 string in UTC.\n\n' +
    'On output a JavaScript `Date` is rendered as an ISO string; on input an ISO ' +
    'string is parsed back into a `Date`. Used for record timestamps (`createdAt`, ' +
    '`updatedAt`) and for a purchase date. Example: "2026-07-18T09:30:00.000Z".',
  serialize: (value: unknown) => (value instanceof Date ? value.toISOString() : value),
  parseValue: (value: unknown) => new Date(value as string),
})

export const builder = new SchemaBuilder<{
  Context: GraphQLContext
  DefaultFieldNullability: false
  Scalars: {
    DateTime: { Input: Date; Output: Date }
    UserId: { Input: UserId; Output: UserId }
    HouseholdId: { Input: HouseholdId; Output: HouseholdId }
    BeverageId: { Input: BeverageId; Output: BeverageId }
    BeverageName: { Input: BeverageName; Output: BeverageName }
    Producer: { Input: Producer; Output: Producer }
    Notes: { Input: Notes; Output: Notes }
    Appellation: { Input: Appellation; Output: Appellation }
    Cuvee: { Input: Cuvee; Output: Cuvee }
    Classification: { Input: Classification; Output: Classification }
    GrapeVariety: { Input: GrapeVariety; Output: GrapeVariety }
    Celsius: { Input: Celsius; Output: Celsius }
    Country: { Input: Country; Output: Country }
    Region: { Input: Region; Output: Region }
    PersonName: { Input: PersonName; Output: PersonName }
    PlaceName: { Input: PlaceName; Output: PlaceName }
    Year: { Input: Year; Output: Year }
    Eur: { Input: Eur; Output: Eur }
    Percentage: { Input: Percentage; Output: Percentage }
    Latitude: { Input: Latitude; Output: Latitude }
    Longitude: { Input: Longitude; Output: Longitude }
    Rating: { Input: Rating; Output: Rating }
    AttachmentId: { Input: AttachmentId; Output: AttachmentId }
    FileName: { Input: FileName; Output: FileName }
    ContentType: { Input: ContentType; Output: ContentType }
    ByteSize: { Input: ByteSize; Output: ByteSize }
    SignedUrl: { Input: SignedUrl; Output: SignedUrl }
  }
}>({
  defaultFieldNullability: false,
})

builder.addScalarType('DateTime', DateTimeScalar)
builder.queryType({})
builder.mutationType({})
