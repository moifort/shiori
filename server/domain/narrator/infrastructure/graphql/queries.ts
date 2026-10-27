import { sagaCountOf } from '~/domain/author/business-rules'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import type { Narrator } from '~/domain/narrator/types'
import {
  type FollowedNarrator,
  type NarratorPage,
  NarratorUseCase,
} from '~/domain/narrator/use-case'
import { FollowedSeriesType } from '~/domain/series/infrastructure/graphql/queries'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'
import { Count } from '~/domain/shared/primitives'

const FollowedNarratorType = builder.objectRef<FollowedNarrator>('FollowedNarrator').implement({
  description:
    'Who reads recordings the reader holds. Derived from the books on every ' +
    'request, never stored.',
  fields: (t) => ({
    key: t.field({ type: 'NarratorKey', resolve: (narrator) => narrator.key }),
    name: t.field({
      type: 'NarratorName',
      description: 'The spelling most of the reader’s recordings use.',
      resolve: (narrator) => narrator.name,
    }),
    portraitUrl: t.field({
      type: 'PortraitUrl',
      nullable: true,
      description: 'Their photograph, when Wikipedia has one. Null: the app draws their initials.',
      resolve: (narrator) => narrator.portraitUrl ?? null,
    }),
    favorite: t.boolean({
      description:
        'The reader hearted the narrator themself, apart from the hearts their ' +
        'recordings and sagas carry.',
      resolve: (narrator) => narrator.favorite === true,
    }),
    bookCount: t.field({
      type: 'Count',
      description: 'Recordings of theirs in the library.',
      resolve: (narrator) => Count(narrator.books.length),
    }),
    readCount: t.field({
      type: 'Count',
      description: 'Recordings of theirs the reader has listened to.',
      resolve: (narrator) => Count(narrator.books.filter((book) => book.status === 'read').length),
    }),
    seriesCount: t.field({
      type: 'Count',
      description: 'Sagas heard in their voice.',
      resolve: (narrator) => Count(sagaCountOf(narrator.seriesIds)),
    }),
    favoriteCount: t.field({
      type: 'Count',
      description: 'Hearted recordings plus hearted sagas.',
      resolve: (narrator) => narrator.favoriteCount,
    }),
    averageRating: t.float({
      nullable: true,
      description:
        'The mean of the stars given to their recordings and sagas. Null when ' +
        'nothing of theirs is rated.',
      resolve: (narrator) => narrator.averageRating ?? null,
    }),
  }),
})

const NarratorCatalogueType = builder.objectRef<Narrator>('Narrator').implement({
  description:
    'What the world knows of a narrator, shared by every reader and built the first ' +
    'time somebody opens their page. Holds nothing of any reader.',
  fields: (t) => ({
    nationality: t.field({
      type: 'Nationality',
      nullable: true,
      resolve: (narrator) => narrator.nationality ?? null,
    }),
    birthYear: t.field({ type: 'Year', nullable: true, resolve: (n) => n.birthYear ?? null }),
    deathYear: t.field({ type: 'Year', nullable: true, resolve: (n) => n.deathYear ?? null }),
    biography: t.field({
      type: 'NarratorBiography',
      nullable: true,
      resolve: (narrator) => narrator.biography ?? null,
    }),
  }),
})

const NarratorPageType = builder.objectRef<NarratorPage>('NarratorPage').implement({
  description: 'Everything a narrator’s page draws, in one answer.',
  fields: (t) => ({
    narrator: t.field({ type: FollowedNarratorType, resolve: (page) => page.narrator }),
    catalogue: t.field({
      type: NarratorCatalogueType,
      nullable: true,
      description:
        'Null when nobody has described the narrator yet, or the model could not: the ' +
        'page still shows the reader’s recordings. A miss is asked about again a month on.',
      resolve: (page) => page.catalogue,
    }),
    awaitingCatalogue: t.boolean({
      description:
        'Answered to `narratorPage(waitForCatalogue: false)` when nobody has described ' +
        'the narrator yet: `catalogue` is null and the page shows the reader’s ' +
        'recordings. The app asks `narratorPage` again with the default, which builds it.',
      resolve: (page) => page.awaitingCatalogue,
    }),
    sagas: t.field({
      type: [FollowedSeriesType],
      description:
        'The reader’s sagas heard in their voice, as the Series tab draws them: the ' +
        'ones listened into first, then those not started, then those set aside.',
      resolve: (page) => page.sagas,
    }),
    books: t.field({
      type: [BookType],
      description: 'The reader’s recordings of theirs outside any saga, listened ones first.',
      resolve: (page) => BookQuery.withSignedCovers(page.books),
    }),
  }),
})

builder.queryFields((t) => ({
  narratorPage: t.field({
    type: NarratorPageType,
    nullable: true,
    description:
      'One narrator’s page: the reader’s recordings in their voice, grouped by saga, ' +
      'and who they are. Built on first sight when nobody has opened it yet: one ' +
      'web-grounded model call for the facts and the biography, in the language of ' +
      '`Accept-Language`, and Wikipedia for the portrait. That first opening takes a ' +
      'few seconds; every later one, by anyone, reads the stored catalogue. Null when ' +
      'the reader holds no recording of theirs and no `offered` names them.',
    args: {
      key: t.arg({ type: 'NarratorKey', required: true }),
      offered: t.arg({
        type: 'NarratorName',
        required: false,
        description:
          'The narrator as a friend’s recording names them, for one the reader holds ' +
          'nothing of. Ignored unless it folds into `key`.',
      }),
      waitForCatalogue: t.arg.boolean({
        required: false,
        defaultValue: true,
        description:
          'False answers at once when nobody has described the narrator: the reader’s ' +
          'recordings with `awaitingCatalogue` set, and no model call. The app draws ' +
          'them, then asks again with the default to build the catalogue.',
      }),
    },
    resolve: (_root, args, { userId, event }) =>
      NarratorUseCase.page(userId, args.key, languageOf(event), args.offered ?? undefined, {
        waitForCatalogue: args.waitForCatalogue ?? true,
      }),
  }),
}))
