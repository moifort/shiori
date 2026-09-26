import type {
  Discovery,
  OfferedVolume,
  SagaDiscovery,
  SagaReleases,
} from '~/domain/discovery/types'
import { FollowedSeriesType } from '~/domain/series/infrastructure/graphql/queries'
import { builder } from '~/domain/shared/graphql/builder'

export const ReleaseFormatEnum = builder.enumType('ReleaseFormat', {
  description: 'How a saga reaches the reader.',
  values: {
    BOOK: { value: 'book', description: 'Printed or electronic: the saga read.' },
    AUDIOBOOK: { value: 'audiobook', description: 'Recorded: the saga heard.' },
  } as const,
})

const StoreEnum = builder.enumType('Store', {
  description: 'Where the reader goes to get a volume.',
  values: {
    AMAZON: { value: 'amazon', description: 'A bookshop, for a printed saga.' },
    AUDIBLE: { value: 'audible', description: 'Audible, for a saga heard.' },
  } as const,
})

const DiscoveredVolumeType = builder.objectRef<OfferedVolume>('DiscoveredVolume').implement({
  description:
    'One volume of a saga the reader does not hold, out or announced, as the weekly web ' +
    'search found it in the language they follow the saga in.',
  fields: (t) => ({
    number: t.field({ type: 'VolumeNumber', resolve: (volume) => volume.number }),
    title: t.field({ type: 'BookTitle', resolve: (volume) => volume.title }),
    date: t.string({
      nullable: true,
      description:
        'When it came out or comes out, as precisely as announced: `YYYY`, `YYYY-MM` or ' +
        '`YYYY-MM-DD`. Null for a volume out on a date nobody found.',
      resolve: (volume) => volume.date ?? null,
    }),
    isbn13: t.field({ type: 'Isbn13', nullable: true, resolve: (volume) => volume.isbn13 ?? null }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      description: 'The publisher’s cover, or the recording’s on Audible.',
      resolve: (volume) => volume.coverUrl ?? null,
    }),
    store: t.field({ type: StoreEnum, resolve: (volume) => volume.store }),
    storeUrl: t.string({
      description:
        'Where to get it: an Amazon search by its ISBN — which lands on the very edition — ' +
        'else by its title; the recording’s own Audible page once Audible confirmed it, ' +
        'else a search for its title.',
      resolve: (volume) => volume.storeUrl,
    }),
  }),
})

export const SagaReleasesType = builder.objectRef<SagaReleases>('SagaReleases').implement({
  description: 'What one saga has for the reader, in the edition they follow.',
  fields: (t) => ({
    watched: t.boolean({
      description:
        'Whether the saga was ever looked up in that language. False until it is: ' +
        '`lookUpSagaReleases` looks it up at once.',
      resolve: (releases) => releases.watched,
    }),
    available: t.field({
      type: [DiscoveredVolumeType],
      description: 'The volumes out the reader does not hold, in order.',
      resolve: (releases) => releases.available,
    }),
    next: t.field({
      type: DiscoveredVolumeType,
      nullable: true,
      description: 'The next volume announced, the soonest first.',
      resolve: (releases) => releases.next ?? null,
    }),
  }),
})

export const SagaDiscoveryType = builder.objectRef<SagaDiscovery>('SagaDiscovery').implement({
  description: 'One row of the Découvrir tab: a saga the reader follows, and what it has for them.',
  fields: (t) => ({
    series: t.field({
      type: FollowedSeriesType,
      description: 'The saga as the Series tab draws its row.',
      resolve: (row) => row.series,
    }),
    available: t.field({
      type: [DiscoveredVolumeType],
      description: 'The volumes out the reader does not hold, in order.',
      resolve: (row) => row.available,
    }),
    next: t.field({
      type: DiscoveredVolumeType,
      nullable: true,
      description: 'The next volume announced.',
      resolve: (row) => row.next ?? null,
    }),
  }),
})

export const DiscoveryType = builder.objectRef<Discovery>('Discovery').implement({
  description: 'The Découvrir tab in one format.',
  fields: (t) => ({
    sagas: t.field({
      type: [SagaDiscoveryType],
      description:
        'A row per saga with something to say: those with volumes to get first, then ' +
        'those with only an announcement, the soonest first.',
      resolve: (discovery) => discovery.sagas,
    }),
    unwatched: t.int({
      description:
        'How many sagas the reader follows in that format were never looked up. Above ' +
        'zero, `lookUpDiscovery` looks them up at once rather than wait for the hourly pass.',
      resolve: (discovery) => discovery.unwatched,
    }),
  }),
})
