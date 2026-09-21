import {
  LibraryArrangementEnum,
  ReadingStatusEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import {
  BookType,
  LibraryPageType,
  LibrarySectionType,
} from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import { builder } from '~/domain/shared/graphql/builder'

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
      'A flat list, not sections: tiered by reading status — reading, to read, ' +
      'read — or by genre then status, and within a status the book most recently ' +
      'started, added or finished first. Read `hasMore`, then pass the id of the ' +
      'last book as `after` for the next page. A cursor naming a book no longer ' +
      'there restarts from the top.',
    args: {
      arrangement: t.arg({
        type: LibraryArrangementEnum,
        defaultValue: 'by-status',
        description: 'By status, or by genre then status.',
      }),
      favorite: t.arg.boolean({
        required: false,
        description: 'Keep only the books the reader marked as favourites.',
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
          arrangement: args.arrangement ?? 'by-status',
          favorite: args.favorite ?? undefined,
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
      'Every subgenre the reader has used across their library, the most used ' +
      'first. What the edit form proposes as they type: a vocabulary drawn from ' +
      'their own shelf. Costs the same scan as the library.',
    resolve: (_root, _args, context) => BookQuery.subgenres(context.userId),
  }),
}))
