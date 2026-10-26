import { FollowedAuthorType } from '~/domain/author/infrastructure/graphql/queries'
import { BookFormatEnum, GenreEnum, heldAs } from '~/domain/book/infrastructure/graphql/enums'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import type { BookView } from '~/domain/book/types'
import type { GenreShelf, LibraryShelves } from '~/domain/library/types'
import { LibraryUseCase } from '~/domain/library/use-case'
import { FollowedSeriesType } from '~/domain/series/infrastructure/graphql/queries'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'
import { Count } from '~/domain/shared/primitives'

const GenreShelfType = builder
  .objectRef<GenreShelf & { cover?: BookView }>('GenreShelf')
  .implement({
    description: 'A genre of the reader library, as the tile of "Par genre" draws it.',
    fields: (t) => ({
      genre: t.field({ type: GenreEnum, resolve: (shelf) => shelf.genre }),
      count: t.field({
        type: 'Count',
        description: 'Books of that genre the view keeps.',
        resolve: (shelf) => Count(shelf.count),
      }),
      cover: t.field({
        type: BookType,
        nullable: true,
        description:
          'The book shelved last of that genre that has a cover, drawn tilted in the ' +
          'tile. Null when none has one.',
        resolve: (shelf) => shelf.cover ?? null,
      }),
    }),
  })

const LibraryShelvesType = builder.objectRef<LibraryShelves>('LibraryShelves')

LibraryShelvesType.implement({
  description:
    'The Library tab entry screen: its pills and its rails, in the view asked. Every ' +
    'field reads the one library scan the request shares: asking for all of them ' +
    'costs one scan, plus the catalogues of the series and the authors drawn.',
  fields: (t) => ({
    formats: t.field({
      type: [BookFormatEnum],
      description:
        'The formats the library holds — under a genre, those of its books — in the ' +
        'order the pills list them. Never narrowed by `format` itself.',
      resolve: (shelves) => LibraryUseCase.formats(shelves.userId, shelves.view),
    }),
    recent: t.field({
      type: [BookType],
      description:
        '"Récemment": every book, newest on `shelvedAt` first. Twenty books at most, covers signed for those alone.',
      resolve: (shelves) => LibraryUseCase.rail(shelves.userId, shelves.view, 'recent'),
    }),
    toRead: t.field({
      type: [BookType],
      description:
        '"Pile à lire": the pile, the book added last first. Twenty books at most, covers signed for those alone.',
      resolve: (shelves) => LibraryUseCase.rail(shelves.userId, shelves.view, 'toRead'),
    }),
    readRecently: t.field({
      type: [BookType],
      description:
        '"Lus récemment": the books read, the one finished last first. Twenty books at most, covers signed for those alone.',
      resolve: (shelves) => LibraryUseCase.rail(shelves.userId, shelves.view, 'readRecently'),
    }),
    favorites: t.field({
      type: [BookType],
      description:
        '"Coups de cœur": the hearted books, newest on `shelvedAt` first. Twenty books at most, covers signed for those alone.',
      args: {
        excludeLovedSeries: t.arg.boolean({
          required: false,
          description:
            'Leave out the volumes of the sagas the reader hearted, which `lovedSeries` ' +
            'draws whole.',
        }),
      },
      resolve: (shelves, args) =>
        args.excludeLovedSeries
          ? LibraryUseCase.favoritesBesideSeries(shelves.userId, shelves.view)
          : LibraryUseCase.rail(shelves.userId, shelves.view, 'favorites'),
    }),
    lovedSeries: t.field({
      type: [FollowedSeriesType],
      description:
        'The sagas of "Coups de cœur": those the reader hearted holding a book of the ' +
        'view, the one shelved last first, set aside or not. Reads those catalogues ' +
        'in one getAll.',
      resolve: (shelves) => LibraryUseCase.lovedSeries(shelves.userId, shelves.view),
    }),
    hasDropped: t.boolean({
      description: 'Whether the view holds a book given up on: the "Abandonnés" row.',
      resolve: (shelves) => LibraryUseCase.hasDropped(shelves.userId, shelves.view),
    }),
    genres: t.field({
      type: [GenreShelfType],
      description: 'The genres of the books the view keeps, the most held first.',
      resolve: (shelves) => LibraryUseCase.genres(shelves.userId, shelves.view),
    }),
    subgenres: t.field({
      type: ['Subgenre'],
      description:
        'Under a `genre`, its subgenres the reader used, the most used first, in the ' +
        'language of `Accept-Language`: the pills of the genre page. Empty otherwise.',
      resolve: (shelves, _args, { event }) =>
        LibraryUseCase.subgenres(shelves.userId, shelves.view, languageOf(event)),
    }),
    series: t.field({
      type: [FollowedSeriesType],
      description:
        'The sagas holding a book of the view, the one shelved last first, a dozen at ' +
        'most; the ones set aside left out. Reads those catalogues in one getAll.',
      resolve: (shelves) => LibraryUseCase.series(shelves.userId, shelves.view),
    }),
    authors: t.field({
      type: [FollowedAuthorType],
      description:
        'The authors of the view books, the one shelved last first, a dozen at most, ' +
        'with their portraits: their catalogues in one getAll.',
      resolve: (shelves) => LibraryUseCase.authors(shelves.userId, shelves.view),
    }),
  }),
})

builder.queryFields((t) => ({
  libraryShelves: t.field({
    type: LibraryShelvesType,
    description:
      'The Library tab entry screen, narrowed to a format pill, or to a genre and one ' +
      'of its subgenres on a genre page. Each rail opens on `libraryPage` with the ' +
      'same filter.',
    args: {
      format: t.arg({ type: BookFormatEnum, required: false, description: 'The format pill' }),
      genre: t.arg({ type: GenreEnum, required: false, description: 'A genre page' }),
      subgenre: t.arg({
        type: 'Subgenre',
        required: false,
        description: 'A subgenre pill of the genre page, matched whatever its case',
      }),
    },
    resolve: (_root, args, { userId }) => ({
      userId,
      view: {
        format: heldAs(args.format).format,
        genre: args.genre ?? undefined,
        subgenre: args.subgenre ?? undefined,
      },
    }),
  }),
}))
