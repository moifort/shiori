import type { Author, AuthorSeries, AuthorWork } from '~/domain/author/types'
import { type AuthorPage, AuthorUseCase, type FollowedAuthor } from '~/domain/author/use-case'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import { FollowedSeriesType } from '~/domain/series/infrastructure/graphql/queries'
import type { SeriesId } from '~/domain/series/types'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'
import { Count } from '~/domain/shared/primitives'

const FollowedAuthorType = builder.objectRef<FollowedAuthor>('FollowedAuthor').implement({
  description:
    'An author the reader holds at least one book of. Derived from the books on ' +
    'every request, never stored.',
  fields: (t) => ({
    key: t.field({ type: 'AuthorKey', resolve: (author) => author.key }),
    name: t.field({
      type: 'AuthorName',
      description: 'The spelling most of the reader’s books use.',
      resolve: (author) => author.name,
    }),
    portraitUrl: t.field({
      type: 'PortraitUrl',
      nullable: true,
      description:
        'Their photograph, once somebody has opened their page and Wikipedia had ' +
        'one. Null until then: the app draws their initials.',
      resolve: (author) => author.portraitUrl ?? null,
    }),
    bookCount: t.field({
      type: 'Count',
      description: 'Books of theirs in the library. A book with two authors counts for both.',
      resolve: (author) => Count(author.books.length),
    }),
    readCount: t.field({
      type: 'Count',
      description: 'Books of theirs the reader has read.',
      resolve: (author) => Count(author.books.filter((book) => book.status === 'read').length),
    }),
    seriesCount: t.field({
      type: 'Count',
      description: 'Sagas those books belong to.',
      resolve: (author) => Count(author.seriesIds.length),
    }),
    favoriteCount: t.field({
      type: 'Count',
      description: 'Hearted books plus hearted sagas: what the list is ranked on first.',
      resolve: (author) => author.favoriteCount,
    }),
    averageRating: t.float({
      nullable: true,
      description:
        'The mean of the stars given to their books and sagas, a heart counting ' +
        'as five. Null when nothing of theirs is rated.',
      resolve: (author) => author.averageRating ?? null,
    }),
    books: t.field({
      type: [BookType],
      description:
        'Their books in the library, newest shelved first: what the tab draws as a ' +
        'strip of covers. Covers are signed only for the rows that select this field.',
      resolve: (author) => BookQuery.withSignedCovers(author.books),
    }),
  }),
})

const AuthorSeriesType = builder
  .objectRef<AuthorSeries & { id: SeriesId }>('AuthorSeries')
  .implement({
    description: 'A saga the author wrote that the reader holds nothing of.',
    fields: (t) => ({
      id: t.field({
        type: 'SeriesId',
        description:
          'The id its catalogue is keyed on: a volume added with this saga membership ' +
          'joins the saga the Series tab and the saga screen know.',
        resolve: (saga) => saga.id,
      }),
      name: t.field({ type: 'SeriesName', resolve: (saga) => saga.name }),
      volumeCount: t.field({
        type: 'VolumeNumber',
        nullable: true,
        description: 'Main volumes out or announced.',
        resolve: (saga) => saga.volumeCount ?? null,
      }),
      firstVolumeTitle: t.field({
        type: 'BookTitle',
        nullable: true,
        description: 'What the saga is started with.',
        resolve: (saga) => saga.firstVolumeTitle ?? null,
      }),
    }),
  })

const AuthorWorkType = builder.objectRef<AuthorWork>('AuthorWork').implement({
  description: 'A book the author wrote outside any saga, that the reader does not hold.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', resolve: (work) => work.title }),
    publishedIn: t.field({
      type: 'Year',
      nullable: true,
      resolve: (work) => work.publishedIn ?? null,
    }),
  }),
})

const AuthorCatalogueType = builder.objectRef<Author>('Author').implement({
  description:
    'What the world knows of an author, shared by every reader and built the first ' +
    'time somebody opens their page. Holds nothing of any reader.',
  fields: (t) => ({
    key: t.field({ type: 'AuthorKey', resolve: (author) => author.key }),
    name: t.field({ type: 'AuthorName', resolve: (author) => author.name }),
    nationality: t.field({
      type: 'Nationality',
      nullable: true,
      resolve: (author) => author.nationality ?? null,
    }),
    birthYear: t.field({ type: 'Year', nullable: true, resolve: (a) => a.birthYear ?? null }),
    deathYear: t.field({ type: 'Year', nullable: true, resolve: (a) => a.deathYear ?? null }),
    biography: t.field({
      type: 'AuthorBiography',
      nullable: true,
      resolve: (author) => author.biography ?? null,
    }),
    portraitUrl: t.field({
      type: 'PortraitUrl',
      nullable: true,
      resolve: (author) => author.portraitUrl ?? null,
    }),
  }),
})

const AuthorPageType = builder.objectRef<AuthorPage>('AuthorPage').implement({
  description: 'Everything an author’s page draws, in one answer.',
  fields: (t) => ({
    author: t.field({ type: FollowedAuthorType, resolve: (page) => page.author }),
    catalogue: t.field({
      type: AuthorCatalogueType,
      nullable: true,
      description:
        'Null when the model could not describe the author: the page still shows the ' +
        'reader’s own books, and the next opening tries again.',
      resolve: (page) => page.catalogue,
    }),
    sagas: t.field({
      type: [FollowedSeriesType],
      description:
        'The reader’s sagas of this author as the Series tab draws them: the ones read ' +
        'into first, then those not started, then those set aside.',
      resolve: (page) => page.sagas,
    }),
    sagasNotHeld: t.field({
      type: [AuthorSeriesType],
      description: 'The author’s other sagas, which the reader holds nothing of.',
      resolve: (page) => page.sagasNotHeld,
    }),
    books: t.field({
      type: [BookType],
      description: 'The reader’s books of this author outside any saga, read ones first.',
      resolve: (page) => BookQuery.withSignedCovers(page.books),
    }),
    booksNotHeld: t.field({
      type: [AuthorWorkType],
      description: 'The author’s other books outside any saga, which the reader does not hold.',
      resolve: (page) => page.booksNotHeld,
    }),
  }),
})

const FollowedAuthorPageType = builder
  .objectRef<{ items: FollowedAuthor[]; hasMore: boolean }>('FollowedAuthorPage')
  .implement({
    description: 'One page of the authors the reader holds books of, plus whether more follow.',
    fields: (t) => ({
      items: t.field({ type: [FollowedAuthorType], resolve: (page) => page.items }),
      hasMore: t.exposeBoolean('hasMore', { description: 'Whether more authors follow this page' }),
    }),
  })

builder.queryFields((t) => ({
  myAuthorsPage: t.field({
    type: FollowedAuthorPageType,
    description:
      'One page of the authors in the library, the ones the reader loves first: ' +
      'most hearts, then the best mean of stars, then the most books, then by name. ' +
      '`favorite` keeps the authors with at least one heart. Offset-paginated: pass ' +
      'the number of rows already shown. Reads the page’s author catalogues, for ' +
      'their portraits, in one getAll.',
    args: {
      limit: t.arg.int({ defaultValue: 40, description: 'Maximum authors in the page' }),
      offset: t.arg.int({ defaultValue: 0, description: 'Rows to skip' }),
      favorite: t.arg.boolean({ required: false, description: 'Only the authors with a heart' }),
    },
    resolve: (_root, args, context) =>
      AuthorUseCase.followedPage(
        context.userId,
        {
          limit: Math.max(1, Math.min(args.limit ?? 40, 200)),
          offset: Math.max(0, args.offset ?? 0),
        },
        { favorite: args.favorite ?? undefined },
      ),
  }),

  authorPage: t.field({
    type: AuthorPageType,
    nullable: true,
    description:
      'One author’s page. Built on first sight when nobody has opened it yet: one ' +
      'web-grounded model call for the facts and the bibliography — titles as the ' +
      'edition the reader holds titles them, the rest in the language of ' +
      '`Accept-Language` — and Wikipedia for the portrait. That first opening takes ' +
      'a few seconds; every later one, by anyone, reads the stored catalogue. Null ' +
      'when the reader holds no book of the author.',
    args: { key: t.arg({ type: 'AuthorKey', required: true }) },
    resolve: (_root, args, { userId, event }) =>
      AuthorUseCase.page(userId, args.key, languageOf(event)),
  }),
}))
