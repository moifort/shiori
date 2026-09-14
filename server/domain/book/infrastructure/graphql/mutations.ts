import { match } from 'ts-pattern'
import { BookCommand } from '~/domain/book/command'
import { ReadingStatusEnum } from '~/domain/book/infrastructure/graphql/enums'
import { BookEditInput, NewBookInput } from '~/domain/book/infrastructure/graphql/inputs'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import type { BookId } from '~/domain/book/types'
import { builder } from '~/domain/shared/graphql/builder'
import { notFound } from '~/domain/shared/graphql/errors'
import type { UserId } from '~/domain/shared/types'

// Commands answer with the record or a bare 'not-found'. Re-reading through the
// query is what attaches the signed cover URL, which the command layer knows
// nothing about — it deals in records, not in presentation.
const readBack = async (userId: UserId, bookId: BookId) => {
  const view = await BookQuery.byId(userId, bookId)
  return view ?? notFound('Book not found')
}

builder.mutationFields((t) => ({
  addBook: t.field({
    type: BookType,
    description:
      'Catalogue a book without scanning it — typed by hand, or taken from a ' +
      'series catalogue. Consumes no scan credit.',
    args: { input: t.arg({ type: NewBookInput, required: true }) },
    resolve: async (_root, args, context) => {
      const book = await BookCommand.add(context.userId, {
        title: args.input.title,
        authors: args.input.authors ?? undefined,
        publisher: args.input.publisher ?? undefined,
        firstPublishedIn: args.input.firstPublishedIn ?? undefined,
        synopsis: args.input.synopsis ?? undefined,
        genres: args.input.genres ?? undefined,
        pageCount: args.input.pageCount ?? undefined,
        isbn13: args.input.isbn13 ?? undefined,
        status: args.input.status ?? undefined,
        hidden: args.input.hidden ?? undefined,
      })
      return readBack(context.userId, book.id)
    },
  }),

  updateBook: t.field({
    type: BookType,
    description: 'Correct a record the scan got wrong. Omitted fields are left alone.',
    args: {
      id: t.arg({ type: 'BookId', required: true }),
      input: t.arg({ type: BookEditInput, required: true }),
    },
    resolve: async (_root, args, context) => {
      const result = await BookCommand.edit(context.userId, args.id, {
        ...(args.input.title !== null && args.input.title !== undefined
          ? { title: args.input.title }
          : {}),
        ...(args.input.authors ? { authors: args.input.authors } : {}),
        ...(args.input.publisher ? { publisher: args.input.publisher } : {}),
        ...(args.input.firstPublishedIn ? { firstPublishedIn: args.input.firstPublishedIn } : {}),
        ...(args.input.synopsis ? { synopsis: args.input.synopsis } : {}),
        ...(args.input.genres ? { genres: args.input.genres } : {}),
        ...(args.input.pageCount ? { pageCount: args.input.pageCount } : {}),
        ...(args.input.isbn13 ? { isbn13: args.input.isbn13 } : {}),
      })
      return match(result)
        .with('not-found', () => notFound('Book not found'))
        .otherwise((book) => readBack(context.userId, book.id))
    },
  }),

  setReadingStatus: t.field({
    type: BookType,
    description:
      'Move a book along the pile. The reading dates follow from the move and are ' +
      'never typed: going back to TO_READ clears them.',
    args: {
      id: t.arg({ type: 'BookId', required: true }),
      status: t.arg({ type: ReadingStatusEnum, required: true }),
    },
    resolve: async (_root, args, context) => {
      const result = await BookCommand.setStatus(context.userId, args.id, args.status)
      return match(result)
        .with('not-found', () => notFound('Book not found'))
        .otherwise((book) => readBack(context.userId, book.id))
    },
  }),

  rateBook: t.field({
    type: BookType,
    description:
      'Give a book one to five stars. Rating marks it as read: the reader is ' +
      'saying they finished it, and leaving it on the pile would make every ' +
      'filter lie.',
    args: {
      id: t.arg({ type: 'BookId', required: true }),
      rating: t.arg({ type: 'StarRating', required: true }),
    },
    resolve: async (_root, args, context) => {
      const result = await BookCommand.rate(context.userId, args.id, args.rating)
      return match(result)
        .with('not-found', () => notFound('Book not found'))
        .otherwise((book) => readBack(context.userId, book.id))
    },
  }),

  setBookNote: t.field({
    type: BookType,
    description: 'Write or replace the reader note. Passing null deletes it.',
    args: {
      id: t.arg({ type: 'BookId', required: true }),
      note: t.arg({ type: 'ReadingNote', required: false }),
    },
    resolve: async (_root, args, context) => {
      const result = await BookCommand.annotate(context.userId, args.id, args.note ?? undefined)
      return match(result)
        .with('not-found', () => notFound('Book not found'))
        .otherwise((book) => readBack(context.userId, book.id))
    },
  }),

  setBookHidden: t.field({
    type: BookType,
    description:
      'Mark a book as excluded from any shared view. Sharing is not built yet; ' +
      'the flag exists now so adding it later costs no migration.',
    args: {
      id: t.arg({ type: 'BookId', required: true }),
      hidden: t.arg.boolean({ required: true }),
    },
    resolve: async (_root, args, context) => {
      const result = await BookCommand.setHidden(context.userId, args.id, args.hidden)
      return match(result)
        .with('not-found', () => notFound('Book not found'))
        .otherwise((book) => readBack(context.userId, book.id))
    },
  }),

  deleteBook: t.boolean({
    description: 'Remove a book from the library for good. Returns true when it was there.',
    args: { id: t.arg({ type: 'BookId', required: true }) },
    resolve: async (_root, args, context) => {
      const result = await BookCommand.remove(context.userId, args.id)
      return match(result)
        .with('removed', () => true)
        .with('not-found', () => notFound('Book not found'))
        .exhaustive()
    },
  }),
}))
