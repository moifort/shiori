import {
  BookFormatEnum,
  GenreEnum,
  heldAs,
  ReadingStatusEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import {
  BookCoverType,
  BookType,
  CoverChoiceType,
  LibraryPageType,
  LibrarySectionType,
  ShelfVocabularyType,
} from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import { BookUseCase } from '~/domain/book/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, notFound } from '~/domain/shared/graphql/errors'
import { languageOf } from '~/domain/shared/language'

/** Covers a search result asks for at once: the rows on one screen, with margin. */
const MAX_COVERS = 50

builder.queryFields((t) => ({
  library: t.field({
    type: [LibrarySectionType],
    description:
      'The reader whole library, grouped into series sections.\n\n' +
      'Filtering by status happens before grouping, so a filter empties a saga ' +
      'section rather than leaving an empty heading behind. Sections are tiered ' +
      'by reading status — reading, to read, read — each saga kept whole, and ' +
      "each tier's standalone books trail its sagas.",
    args: {
      status: t.arg({
        type: ReadingStatusEnum,
        required: false,
        description: 'Keep only books in this status. Omit for the whole library.',
      }),
    },
    resolve: (_root, args, context) => BookQuery.library(context.userId, args.status ?? undefined),
  }),

  libraryPage: t.field({
    type: LibraryPageType,
    description:
      'One page of the Library tab, for a list that draws as it scrolls.\n\n' +
      'A flat list, not sections: newest first on `shelvedAt` — the day each book ' +
      'was finished, else started, else added. With no `status`, every book is ' +
      'there, the dropped ones included. The app cuts ' +
      'it into month sections on that date. Read `hasMore`, then pass the id of the ' +
      'last book as `after` for the next page. A cursor naming a book no longer ' +
      'there restarts from the top.',
    args: {
      favorite: t.arg.boolean({
        required: false,
        description:
          'Keep only the books the reader hearted, newest first as everywhere else: the ' +
          '"Favoris" filter, where `loved` is the favourites view.',
      }),
      loved: t.arg.boolean({
        required: false,
        description:
          'The favourites view: every book the reader judged — its own heart or ' +
          "stars, else its saga's once it is read — hearts first, then five stars " +
          'down to one, each rank newest on `shelvedAt` first. The app cuts it into ' +
          'one section per rank rather than per month.',
        deprecationReason:
          'The Library tab has no favourites view any more: "Coups de cœur" is `favorite`.',
      }),
      status: t.arg({
        type: ReadingStatusEnum,
        required: false,
        description: 'Keep only books in this status. Omit for the whole library.',
      }),
      format: t.arg({
        type: BookFormatEnum,
        required: false,
        description: 'Keep only books of this format: the pill over the grid.',
      }),
      genre: t.arg({
        type: GenreEnum,
        required: false,
        description:
          'Keep only books of this genre: a shelf opened from the genre page. Ordered in ' +
          'memory from the library scan, which a genre needs no index for.',
      }),
      subgenre: t.arg({
        type: 'Subgenre',
        required: false,
        description: 'Keep only books carrying this subgenre, whatever its case.',
      }),
      limit: t.arg.int({ defaultValue: 60, description: 'Maximum books in the page' }),
      after: t.arg({
        type: 'BookId',
        required: false,
        description: 'Cursor: the last book of the previous page',
      }),
    },
    resolve: (_root, args, context) =>
      BookQuery.libraryPage(
        context.userId,
        { limit: Math.max(1, Math.min(args.limit ?? 60, 200)), after: args.after ?? undefined },
        {
          favorite: args.favorite ?? undefined,
          loved: args.loved ?? undefined,
          status: args.status ?? undefined,
          format: heldAs(args.format).format,
          genre: args.genre ?? undefined,
          subgenre: args.subgenre ?? undefined,
        },
      ),
  }),

  librarySearchIndex: t.field({
    type: [BookType],
    description:
      'Every book of the reader, for the search the app runs on the phone as they ' +
      'type: fetched once and kept on the device, never asked per keystroke.\n\n' +
      '`coverUrl` is always null here: signing the whole library would cost more than ' +
      'the search, and a signature outlives no index kept for days. Ask `bookCovers` ' +
      'for the rows drawn. One scan of the library.',
    resolve: (_root, _args, context) => BookQuery.searchIndex(context.userId),
  }),

  bookCoverChoices: t.field({
    type: [CoverChoiceType],
    description:
      'The covers the reader may pick for one of their books, for `chooseBookCover`: ' +
      'the one drawn now first, then what the record holds — the Kindle cover, the ' +
      'scan photo, the publisher cover — and what Amazon and Open Library have for its ' +
      'ISBN and for up to three other editions in its language. Each image once. ' +
      'Free: no model call, no scan spent; a source that does not answer within a few ' +
      'seconds is a cover not offered. NOT_FOUND when the reader has no such book.',
    args: { id: t.arg({ type: 'BookId', required: true }) },
    resolve: async (_root, args, context) => {
      const choices = await BookUseCase.coverChoices(context.userId, args.id)
      return choices === 'not-found' ? notFound('Book not found') : choices
    },
  }),

  bookCovers: t.field({
    type: [BookCoverType],
    description:
      'The covers of the reader books named, signed for these alone: what a search ' +
      'result draws, the index carrying none. A book not theirs is left out. At most ' +
      `${MAX_COVERS} ids; one document read each.`,
    args: { ids: t.arg({ type: ['BookId'], required: true }) },
    resolve: (_root, args, context) => {
      if (args.ids.length > MAX_COVERS) badUserInput(`At most ${MAX_COVERS} covers per request`)
      return BookQuery.covers(context.userId, args.ids)
    },
  }),

  book: t.field({
    type: BookType,
    nullable: true,
    description: 'One book of the reader library. Null when they do not own it.',
    args: { id: t.arg({ type: 'BookId', required: true }) },
    resolve: (_root, args, context) => BookQuery.byId(context.userId, args.id),
  }),

  subgenres: t.field({
    type: ['Subgenre'],
    description:
      'Every subgenre the reader has used across their library in the language of ' +
      '`Accept-Language`, the most used first. What the edit form proposes as they ' +
      'type: a vocabulary drawn from their own shelf, in the language they type in. ' +
      'Costs the same scan as the library.',
    resolve: (_root, _args, context) =>
      BookQuery.subgenres(context.userId, languageOf(context.event)),
  }),

  vocabulary: t.field({
    type: ShelfVocabularyType,
    description:
      'The reader subgenres and the sagas they hold, together: what the edit form ' +
      'proposes as they type, in one request and one scan of the library, where ' +
      '`subgenres` and `mySeries` asked apart would cost two scans and a catalogue read.',
    resolve: (_root, _args, context) =>
      BookQuery.vocabulary(context.userId, languageOf(context.event)),
  }),
}))
