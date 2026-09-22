import { ReadingStatusEnum } from '~/domain/book/infrastructure/graphql/enums'
import {
  BookType,
  LibraryPageType,
  LibrarySectionType,
  ShelfVocabularyType,
} from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

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
      'was finished, else started, else added — whatever its status. The app cuts ' +
      'it into month sections on that date — or, with `rated`, best first and cut ' +
      'by stars. Read `hasMore`, then pass the id of the ' +
      'last book as `after` for the next page. A cursor naming a book no longer ' +
      'there restarts from the top.',
    args: {
      favorite: t.arg.boolean({
        required: false,
        description: 'Keep only the books the reader marked as favourites.',
      }),
      rated: t.arg.boolean({
        required: false,
        deprecationReason:
          'A heart is five stars, so the favourites are the best rated: the app no ' +
          'longer has a rated view. Kept for the builds that still send it.',
        description:
          'Keep only the books that show stars, the best first: rated by hand, or ' +
          'through their saga (`seriesRating`). Within one band of stars, the order ' +
          'of the shelf. The app cuts the page into sections by stars rather than by month.',
      }),
      status: t.arg({
        type: ReadingStatusEnum,
        required: false,
        description: 'Keep only books in this status. Omit for the whole library.',
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
          rated: args.rated ?? undefined,
          status: args.status ?? undefined,
        },
      ),
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
