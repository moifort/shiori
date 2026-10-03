import { AudibleQuery } from '~/domain/audible/query'
import { FollowedAuthorType } from '~/domain/author/infrastructure/graphql/queries'
import type {
  AnnouncedVolumePreview,
  AuthorDiscovery,
  AuthorReleases,
  Discovery,
  FoundVolume,
  FoundWork,
  SagaDiscovery,
  SagaReleases,
} from '~/domain/discovery/types'
import { ScanResultType } from '~/domain/scan/infrastructure/graphql/types'
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
    'One volume of a saga the reader does not hold, announced or just out, as the web search ' +
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
    audibleUrl: t.string({
      nullable: true,
      description:
        "The recording's page on the reader's Audible store, `https://www.audible.{marketplace}/pd/{asin}`, " +
        'which the Audible app opens on the title. Null on a volume of a saga read, on a ' +
        'recording Audible never confirmed, and without an Audible account.',
      resolve: async (volume, _args, { userId }) =>
        volume.asin ? ((await AudibleQuery.recordingUrlOf(userId, volume.asin)) ?? null) : null,
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
    recent: t.field({
      type: [DiscoveredVolumeType],
      description:
        'The volumes out in the last two weeks, on a known day, that the reader does not hold and ' +
        'can have now — a recording Audible confirmed, a printed book with an ISBN Amazon ' +
        'did not turn down — the newest first. Read off the same watch as `next`: a ' +
        'volume announced moves here on its day.',
      resolve: (row) => row.recent,
    }),
  }),
})

const DiscoveredWorkType = builder.objectRef<FoundWork>('DiscoveredWork').implement({
  description:
    'One work of an author the reader does not hold, announced or just out, outside any saga ' +
    'they hold, as the web search found it in the language and format they hold the ' +
    'author in.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', resolve: (work) => work.title }),
    date: t.string({
      nullable: true,
      description:
        'When it comes out or came out, as precisely as announced: `YYYY`, `YYYY-MM` or ' +
        '`YYYY-MM-DD`.',
      resolve: (work) => work.date ?? null,
    }),
    isbn13: t.field({ type: 'Isbn13', nullable: true, resolve: (work) => work.isbn13 ?? null }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      description: 'The publisher’s cover, or the recording’s on Audible.',
      resolve: (work) => work.coverUrl ?? null,
    }),
    audibleUrl: t.string({
      nullable: true,
      description:
        "The recording's page on the reader's Audible store. Null on a printed work, on a " +
        'recording Audible never confirmed, and without an Audible account.',
      resolve: async (work, _args, { userId }) =>
        work.asin ? ((await AudibleQuery.recordingUrlOf(userId, work.asin)) ?? null) : null,
    }),
    seriesName: t.field({
      type: 'SeriesName',
      nullable: true,
      description: 'The new saga it opens, when it is a volume of one.',
      resolve: (work) => work.seriesName ?? null,
    }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      description: 'Its number in that saga.',
      resolve: (work) => work.volume ?? null,
    }),
  }),
})

const recentWorksDescription =
  'The works out in the last three months — dated to the day, or to a month over — the ' +
  'newest first, a recording Audible never confirmed included, without its `audibleUrl`.'

export const AuthorReleasesType = builder.objectRef<AuthorReleases>('AuthorReleases').implement({
  description:
    'What one author has for the reader in one format, outside the sagas they hold: the ' +
    'author page’s "Annoncés" and "Nouveautés".',
  fields: (t) => ({
    next: t.field({
      type: DiscoveredWorkType,
      nullable: true,
      description: 'The soonest work announced, to the day, the month or the year.',
      resolve: (releases) => releases.next ?? null,
    }),
    recent: t.field({
      type: [DiscoveredWorkType],
      description: recentWorksDescription,
      resolve: (releases) => releases.recent,
    }),
  }),
})

export const AuthorDiscoveryType = builder.objectRef<AuthorDiscovery>('AuthorDiscovery').implement({
  description:
    'One row of the Découvrir tab’s Authors shelf: an author the reader holds, and what they ' +
    'brought out lately or announced outside the sagas the reader holds.',
  fields: (t) => ({
    author: t.field({
      type: FollowedAuthorType,
      description: 'The author as the Library’s Authors shelf draws their row.',
      resolve: (row) => row.author,
    }),
    next: t.field({
      type: DiscoveredWorkType,
      nullable: true,
      description: 'The soonest work announced, to the day, the month or the year.',
      resolve: (row) => row.next ?? null,
    }),
    recent: t.field({
      type: [DiscoveredWorkType],
      description: recentWorksDescription,
      resolve: (row) => row.recent,
    }),
    sagas: t.field({
      type: [SagaDiscoveryType],
      description:
        'The rows of `sagas` that are theirs — who wrote a saga read off the reader’s own ' +
        'volumes — in the same order: the volumes announced or just out the Books shelf ' +
        'lists are their news too.',
      resolve: (row) => row.sagas,
    }),
  }),
})

export const DiscoveryType = builder.objectRef<Discovery>('Discovery').implement({
  description: 'The Découvrir tab in one format.',
  fields: (t) => ({
    sagas: t.field({
      type: [SagaDiscoveryType],
      description:
        'A row per saga with a volume announced for a known date, the soonest first, then ' +
        'a row per saga with nothing announced but a volume just out, the newest first.',
      resolve: (discovery) => discovery.sagas,
    }),
    authors: t.field({
      type: [AuthorDiscoveryType],
      description:
        'A row per author the reader holds in that format — all but the ones whose every ' +
        'book they gave up on — with a work announced for a known date, the soonest first, ' +
        'then a row per author with nothing announced but a work just out, the newest ' +
        'first, then the authors with nothing of their own but an edition awaited or a saga ' +
        'among `sagas`. The volumes of a saga the reader holds stay in `sagas`, each author ' +
        'naming theirs.',
      resolve: (discovery) => discovery.authors,
    }),
    unwatched: t.int({
      description:
        'How many sagas and authors the reader follows in that format were never looked ' +
        'up. Above zero, `lookUpDiscovery` looks them up at once rather than wait for the ' +
        'hourly pass.',
      resolve: (discovery) => discovery.unwatched,
    }),
    followed: t.int({
      description:
        'How many sagas and authors the reader follows in that format. Zero, and the app ' +
        'opens Découvrir on the other format.',
      resolve: (discovery) => discovery.followed,
    }),
  }),
})

export const AnnouncedVolumePreviewType = builder
  .objectRef<AnnouncedVolumePreview>('AnnouncedVolumePreview')
  .implement({
    description:
      'A volume announced, described for its page before the reader adds it: the record a ' +
      'scan would propose, and what only a recording has.',
    fields: (t) => ({
      book: t.field({
        type: ScanResultType,
        description:
          'The record, placed in its saga at its number and in its edition’s language. ' +
          'Hand it to `addBook` to add the volume.',
        resolve: (preview) => preview.book,
      }),
      narrators: t.field({
        type: ['NarratorName'],
        description: 'Who reads the recording, as Audible lists them. Empty for a printed volume.',
        resolve: (preview) => preview.narrators,
      }),
      durationMinutes: t.int({
        nullable: true,
        description: 'The recording’s running time, as Audible gives it.',
        resolve: (preview) => preview.durationMinutes ?? null,
      }),
      releaseDate: t.string({
        nullable: true,
        description:
          'When it comes out, as precisely as announced: `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.',
        resolve: (preview) => preview.releaseDate ?? null,
      }),
      audibleUrl: t.string({
        nullable: true,
        description:
          "The recording's page on the reader's Audible store. Null on a printed volume, " +
          'on a recording Audible never confirmed, and without an Audible account.',
        resolve: async (preview, _args, { userId }) =>
          preview.asin ? ((await AudibleQuery.recordingUrlOf(userId, preview.asin)) ?? null) : null,
      }),
    }),
  })
