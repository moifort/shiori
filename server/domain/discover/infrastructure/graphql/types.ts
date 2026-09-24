import { audibleSearchUrlOf } from '~/domain/audible/business-rules'
import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import type { Discover, TranslatedEdition, Translation } from '~/domain/discover/types'
import { builder } from '~/domain/shared/graphql/builder'

const TranslationFormatEnum = builder.enumType('TranslationFormat', {
  description: 'How a translation reaches the reader.',
  values: {
    BOOK: { value: 'book', description: 'Printed or electronic.' },
    AUDIOBOOK: { value: 'audiobook', description: 'Recorded.' },
  } as const,
})

const TranslationKindEnum = builder.enumType('TranslationKind', {
  description: 'Whether the reader read a whole saga or one book on its own.',
  values: {
    SERIES: { value: 'series' },
    BOOK: { value: 'book' },
  } as const,
})

/** An edition, with the translation it belongs to, which knows the reader's
 *  Audible store. */
type EditionView = { edition: TranslatedEdition; translation: Translation }

const TranslatedEditionType = builder.objectRef<EditionView>('TranslatedEdition').implement({
  description:
    'One edition of a work in the app’s language, out or announced. A recording is ' +
    'only ever listed for a reader connected to Audible.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', resolve: ({ edition }) => edition.title }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      resolve: ({ edition }) => edition.volume ?? null,
    }),
    format: t.field({ type: TranslationFormatEnum, resolve: ({ edition }) => edition.format }),
    date: t.string({
      nullable: true,
      description:
        'When it came out or comes out, as precisely as announced: `YYYY`, `YYYY-MM` or ' +
        '`YYYY-MM-DD`. Null for an edition out on a date nobody found.',
      resolve: ({ edition }) => edition.date ?? null,
    }),
    audibleUrl: t.string({
      nullable: true,
      description:
        'For a recording, a search for its title on the reader’s own Audible store — ' +
        'where the reader goes to find it; Shiori never reads the catalogue.',
      resolve: ({ edition, translation }) =>
        edition.format === 'audiobook' && translation.audibleMarketplace
          ? audibleSearchUrlOf(translation.audibleMarketplace, edition.title)
          : null,
    }),
  }),
})

const TranslationType = builder.objectRef<Translation>('Translation').implement({
  description:
    'A saga or a book the reader read in another language, with what exists or is ' +
    'announced of it in the app’s language.',
  fields: (t) => ({
    key: t.string({
      description: 'What `dismissTranslation` names.',
      resolve: (translation) => translation.key,
    }),
    kind: t.field({ type: TranslationKindEnum, resolve: (translation) => translation.kind }),
    title: t.field({
      type: 'BookTitle',
      description: 'Its title in the app’s language, else the one the reader knows.',
      resolve: (translation) => translation.title,
    }),
    originalTitle: t.field({
      type: 'BookTitle',
      description: 'The saga’s name or the book’s title as the reader catalogued it.',
      resolve: (translation) => translation.originalTitle,
    }),
    author: t.field({
      type: 'AuthorName',
      nullable: true,
      resolve: (translation) => translation.author ?? null,
    }),
    originalLanguage: t.field({
      type: BookLanguageEnum,
      description: 'The language the reader read it in.',
      resolve: (translation) => translation.originalLanguage,
    }),
    volumesRead: t.field({
      type: ['VolumeNumber'],
      description: 'The volumes of a saga the reader read or is reading.',
      resolve: (translation) => translation.volumesRead,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      resolve: (translation) => translation.coverUrl ?? null,
    }),
    nextDate: t.string({
      nullable: true,
      description: 'The soonest edition still to come, as precisely as announced.',
      resolve: (translation) => translation.nextDate ?? null,
    }),
    editions: t.field({
      type: [TranslatedEditionType],
      description: 'Every edition, by volume then by date.',
      resolve: (translation) => translation.editions.map((edition) => ({ edition, translation })),
    }),
  }),
})

export const DiscoverType = builder.objectRef<Discover>('Discover').implement({
  description:
    'The Découvrir tab: the books the reader read in another language, now out or ' +
    'coming out in the app’s language.',
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
      type: [TranslationType],
      description: 'Works with at least one edition still to come, the soonest first.',
      resolve: (discover) => discover.upcoming,
    }),
    available: t.field({
      type: [TranslationType],
      description: 'Works already out in the app’s language, the most recently read first.',
      resolve: (discover) => discover.available,
    }),
  }),
})
