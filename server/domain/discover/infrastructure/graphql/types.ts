import { audibleSearchUrlOf } from '~/domain/audible/business-rules'
import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import type { Discover, Release, ReleaseEdition } from '~/domain/discover/types'
import { FollowedSeriesType } from '~/domain/series/infrastructure/graphql/queries'
import { builder } from '~/domain/shared/graphql/builder'

const ReleaseFormatEnum = builder.enumType('ReleaseFormat', {
  description: 'How an edition reaches the reader.',
  values: {
    BOOK: { value: 'book', description: 'Printed or electronic.' },
    AUDIOBOOK: { value: 'audiobook', description: 'Recorded.' },
  } as const,
})

const ReleaseKindEnum = builder.enumType('ReleaseKind', {
  description: 'Whether the release is of a saga, or of one book on its own.',
  values: {
    SERIES: { value: 'series' },
    BOOK: { value: 'book' },
  } as const,
})

/** An edition, with the release it belongs to, which knows the reader's
 *  Audible store. */
type EditionView = { edition: ReleaseEdition; release: Release }

const ReleaseEditionType = builder.objectRef<EditionView>('ReleaseEdition').implement({
  description:
    'One edition of a work in one language, out or announced. A recording is only ever ' +
    'listed for a reader connected to Audible.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', resolve: ({ edition }) => edition.title }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      resolve: ({ edition }) => edition.volume ?? null,
    }),
    format: t.field({ type: ReleaseFormatEnum, resolve: ({ edition }) => edition.format }),
    date: t.string({
      nullable: true,
      description:
        'When it came out or comes out, as precisely as announced: `YYYY`, `YYYY-MM` or ' +
        '`YYYY-MM-DD`. Null for an edition out on a date nobody found.',
      resolve: ({ edition }) => edition.date ?? null,
    }),
    isbn13: t.field({
      type: 'Isbn13',
      nullable: true,
      resolve: ({ edition }) => edition.isbn13 ?? null,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      description: 'The publisher’s cover of this edition, found by its ISBN.',
      resolve: ({ edition }) => edition.coverUrl ?? null,
    }),
    audibleUrl: t.string({
      nullable: true,
      description:
        'For a recording, a search for its title on the reader’s own Audible store — ' +
        'where the reader goes to find it; Shiori never reads the catalogue.',
      resolve: ({ edition, release }) =>
        edition.format === 'audiobook' && release.audibleMarketplace
          ? audibleSearchUrlOf(release.audibleMarketplace, edition.title)
          : null,
    }),
  }),
})

const ReleaseType = builder.objectRef<Release>('Release').implement({
  description:
    'A saga the reader follows, or a book they read, in one language: what exists or is ' +
    'announced of it there. A saga read in English whose French translation is ' +
    'announced makes two releases, one per language, as the Series tab makes two rows.',
  fields: (t) => ({
    key: t.string({
      description: 'What `dismissRelease` names.',
      resolve: (release) => release.key,
    }),
    kind: t.field({ type: ReleaseKindEnum, resolve: (release) => release.kind }),
    seriesId: t.field({
      type: 'SeriesId',
      nullable: true,
      resolve: (release) => release.seriesId ?? null,
    }),
    language: t.field({
      type: BookLanguageEnum,
      description: 'The language of its editions.',
      resolve: (release) => release.language,
    }),
    readIn: t.field({
      type: BookLanguageEnum,
      description: 'The language the reader read it in.',
      resolve: (release) => release.readIn,
    }),
    title: t.field({
      type: 'BookTitle',
      description: 'Its title in that language, else the one the reader knows.',
      resolve: (release) => release.title,
    }),
    author: t.field({
      type: 'AuthorName',
      nullable: true,
      resolve: (release) => release.author ?? null,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      resolve: (release) => release.coverUrl ?? null,
    }),
    nextDate: t.string({
      nullable: true,
      description: 'The soonest edition still to come, as precisely as announced.',
      resolve: (release) => release.nextDate ?? null,
    }),
    editions: t.field({
      type: [ReleaseEditionType],
      description: 'Every edition the reader does not own, by volume then by date.',
      resolve: (release) => release.editions.map((edition) => ({ edition, release })),
    }),
    series: t.field({
      type: FollowedSeriesType,
      nullable: true,
      description:
        'For a saga, its row as the Series tab draws it in that language, the catalogue ' +
        'carrying the dates the release watch wrote. A language the reader holds nothing ' +
        'in answers a row with no volumes of its own and no state.',
      resolve: (release) => release.series ?? null,
    }),
  }),
})

export const DiscoverType = builder.objectRef<Discover>('Discover').implement({
  description:
    'The Découvrir tab: what is coming next in the sagas the reader follows, in the ' +
    'language they read each in and in the app’s, and what may interest them.',
  fields: (t) => ({
    preparedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description: 'When the daily refresh last ran. Null before the first.',
      resolve: (discover) => discover.preparedAt ?? null,
    }),
    canRefresh: t.boolean({
      description: 'Whether `refreshDiscover` would look again now: once a day at most.',
      resolve: (discover) => discover.canRefresh,
    }),
    upcoming: t.field({
      type: [ReleaseType],
      description: 'Works with an edition still to come, the soonest first.',
      resolve: (discover) => discover.upcoming,
    }),
    maybe: t.field({
      type: [ReleaseType],
      description:
        'Works the reader may want. For now, a translation already out in the app’s ' +
        'language of what they read in another, the most recently read first.',
      resolve: (discover) => discover.maybe,
    }),
  }),
})
