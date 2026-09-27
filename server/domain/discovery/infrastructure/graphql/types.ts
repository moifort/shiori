import type { Discovery, FoundVolume, SagaDiscovery, SagaReleases } from '~/domain/discovery/types'
import { FollowedSeriesType } from '~/domain/series/infrastructure/graphql/queries'
import { builder } from '~/domain/shared/graphql/builder'

export const ReleaseFormatEnum = builder.enumType('ReleaseFormat', {
  description: 'How a saga reaches the reader.',
  values: {
    BOOK: { value: 'book', description: 'Printed or electronic: the saga read.' },
    AUDIOBOOK: { value: 'audiobook', description: 'Recorded: the saga heard.' },
  } as const,
})

const DiscoveredVolumeType = builder.objectRef<FoundVolume>('DiscoveredVolume').implement({
  description:
    'One volume of a saga the reader does not hold, announced, as the weekly web search ' +
    'found it in the language they follow the saga in.',
  fields: (t) => ({
    number: t.field({ type: 'VolumeNumber', resolve: (volume) => volume.number }),
    title: t.field({ type: 'BookTitle', resolve: (volume) => volume.title }),
    date: t.string({
      nullable: true,
      description:
        'When it comes out, as precisely as announced: `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. ' +
        'Null for a volume announced for a date nobody found.',
      resolve: (volume) => volume.date ?? null,
    }),
    isbn13: t.field({ type: 'Isbn13', nullable: true, resolve: (volume) => volume.isbn13 ?? null }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      description: 'The publisher’s cover, or the recording’s on Audible.',
      resolve: (volume) => volume.coverUrl ?? null,
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
    missing: t.field({
      type: ['VolumeNumber'],
      description:
        'The numbers of the volumes out the reader has not added, in order — the ones the ' +
        'Series tab draws missing, which the saga screen adds.',
      resolve: (row) => row.missing,
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
      description: 'A row per saga with a volume announced for a known date, the soonest first.',
      resolve: (discovery) => discovery.sagas,
    }),
    unwatched: t.int({
      description:
        'How many sagas the reader follows in that format were never looked up. Above ' +
        'zero, `lookUpDiscovery` looks them up at once rather than wait for the hourly pass.',
      resolve: (discovery) => discovery.unwatched,
    }),
    followed: t.int({
      description:
        'How many sagas the reader follows in that format. Zero, and the app opens ' +
        'Découvrir on the other format.',
      resolve: (discovery) => discovery.followed,
    }),
  }),
})
