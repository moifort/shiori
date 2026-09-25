import type { FeaturedSaga, FollowedAuthor } from '~/domain/author/types'
import { AuthorUseCase } from '~/domain/author/use-case'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { FollowedSeriesType } from '~/domain/series/infrastructure/graphql/queries'
import { builder } from '~/domain/shared/graphql/builder'
import { Count } from '~/domain/shared/primitives'

const FeaturedSagaType = builder.objectRef<FeaturedSaga>('AuthorSaga').implement({
  description:
    'The saga shown under an author: their latest in progress, else their latest ' +
    'finished. A saga not started or set aside is never shown.',
  fields: (t) => ({
    series: t.field({ type: FollowedSeriesType, resolve: (saga) => saga.series }),
    readCount: t.exposeInt('readCount', {
      description:
        'Volumes read: on the published spine when the saga is catalogued, else ' +
        'among the volumes owned.',
    }),
    totalCount: t.exposeInt('totalCount', {
      description:
        'Volumes to read: the published spine when the saga is catalogued, else ' +
        'the volumes owned — which is the only count there is then.',
    }),
  }),
})

const FollowedAuthorType = builder.objectRef<FollowedAuthor<Book>>('FollowedAuthor').implement({
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
    bookCount: t.field({
      type: 'Count',
      description: 'Books of theirs in the library. A book with two authors counts for both.',
      resolve: (author) => Count(author.books.length),
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
    saga: t.field({
      type: FeaturedSagaType,
      nullable: true,
      description:
        'Their saga to show under the covers. Null when none is in progress or finished.',
      resolve: (author) => author.saga,
    }),
  }),
})

const FollowedAuthorPageType = builder
  .objectRef<{ items: FollowedAuthor<Book>[]; hasMore: boolean }>('FollowedAuthorPage')
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
      'the number of rows already shown. Reads the catalogues of the page’s sagas ' +
      'only.',
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
}))
