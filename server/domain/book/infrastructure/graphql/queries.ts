import { ReadingStatusEnum } from '~/domain/book/infrastructure/graphql/enums'
import { BookType, LibrarySectionType } from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import { builder } from '~/domain/shared/graphql/builder'

builder.queryFields((t) => ({
  library: t.field({
    type: [LibrarySectionType],
    description:
      'The reader whole library, grouped into series sections.\n\n' +
      'Filtering by status happens before grouping, so a filter empties a saga ' +
      'section rather than leaving an empty heading behind. Sections are sorted ' +
      'by series name, and the standalone shelf trails them.',
    args: {
      status: t.arg({
        type: ReadingStatusEnum,
        required: false,
        description: 'Keep only books in this status. Omit for the whole library.',
      }),
    },
    resolve: (_root, args, context) => BookQuery.library(context.userId, args.status ?? undefined),
  }),

  book: t.field({
    type: BookType,
    nullable: true,
    description: 'One book of the reader library. Null when they do not own it.',
    args: { id: t.arg({ type: 'BookId', required: true }) },
    resolve: (_root, args, context) => BookQuery.byId(context.userId, args.id),
  }),

  currentlyReading: t.field({
    type: [BookType],
    description:
      'What the reader has open right now, most recently started first. The home ' +
      'screen is built on this.',
    resolve: (_root, _args, context) => BookQuery.currentlyReading(context.userId),
  }),
}))
