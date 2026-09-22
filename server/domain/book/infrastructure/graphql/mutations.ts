import { match } from 'ts-pattern'
import { taggedIn } from '~/domain/book/business-rules'
import type { BookEdit } from '~/domain/book/command'
import { ReadingStatusEnum } from '~/domain/book/infrastructure/graphql/enums'
import { BookEditInput, NewBookInput } from '~/domain/book/infrastructure/graphql/inputs'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { MAX_NARRATORS, MAX_SUBGENRES } from '~/domain/book/primitives'
import { BookQuery } from '~/domain/book/query'
import type { BookId } from '~/domain/book/types'
import { BookUseCase } from '~/domain/book/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, notFound } from '~/domain/shared/graphql/errors'
import { languageOf } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'

// Commands answer with the record or a bare 'not-found'. Re-reading through the
// query is what attaches the signed cover URL, which the command layer knows
// nothing about — it deals in records, not in presentation.
const readBack = async (userId: UserId, bookId: BookId) => {
  const view = await BookQuery.byId(userId, bookId)
  return view ?? notFound('Book not found')
}

// GraphQL tells an omitted field (undefined) from an explicit null. Omitted is
// left alone; null clears, which the command expresses as an undefined value
// the repository then drops from the document.
const clearable = <Key extends keyof BookEdit>(
  key: Key,
  value: BookEdit[Key] | null | undefined,
) => (value === undefined ? {} : { [key]: value ?? undefined })

builder.mutationFields((t) => ({
  addBook: t.field({
    type: BookType,
    description:
      'Catalogue a book without scanning it — typed by hand, or taken from a ' +
      'series catalogue. Consumes no scan credit.',
    args: { input: t.arg({ type: NewBookInput, required: true }) },
    resolve: async (_root, args, context) => {
      const book = await BookUseCase.add(context.userId, {
        title: args.input.title,
        authors: args.input.authors ?? undefined,
        format: args.input.format ?? undefined,
        publisher: args.input.publisher ?? undefined,
        firstPublishedIn: args.input.firstPublishedIn ?? undefined,
        synopsis: args.input.synopsis ?? undefined,
        genre: args.input.genre ?? undefined,
        // A new book's subgenres come from its scan, written in the language of the
        // edition — or of the app, when the scan could not tell the edition's.
        subgenres: args.input.subgenres
          ? taggedIn(
              args.input.subgenres.slice(0, MAX_SUBGENRES),
              args.input.language ?? languageOf(context.event),
            )
          : undefined,
        pageCount: args.input.pageCount ?? undefined,
        narrators: args.input.narrators?.slice(0, MAX_NARRATORS) ?? undefined,
        language: args.input.language ?? undefined,
        isbn13: args.input.isbn13 ?? undefined,
        series: args.input.series
          ? {
              id: args.input.series.id,
              name: args.input.series.name,
              volume: args.input.series.volume ?? undefined,
              kind: args.input.series.kind,
            }
          : undefined,
        publishedCoverUrl: args.input.coverUrl ?? undefined,
        status: args.input.status ?? undefined,
        hidden: args.input.hidden ?? undefined,
      })
      return readBack(context.userId, book.id)
    },
  }),

  updateBook: t.field({
    type: BookType,
    description:
      'Correct a record the scan got wrong. Omitted fields are left alone; an ' +
      'optional field passed as null is cleared. BAD_USER_INPUT when `series` names ' +
      'a saga the reader does not hold and the book has no author to key it with.',
    args: {
      id: t.arg({ type: 'BookId', required: true }),
      input: t.arg({ type: BookEditInput, required: true }),
    },
    resolve: async (_root, args, context) => {
      const { input } = args
      const result = await BookUseCase.edit(context.userId, args.id, {
        // Title and format have no absent state, so a null for them is ignored.
        ...(input.title != null ? { title: input.title } : {}),
        ...(input.format != null ? { format: input.format } : {}),
        // Lists clear to empty rather than to absent: the record always has them.
        ...(input.authors !== undefined ? { authors: input.authors ?? [] } : {}),
        // Typed by the reader, so in the language of their app — except the labels
        // the book already carried, which the command leaves in their own.
        ...(input.subgenres !== undefined
          ? {
              subgenres: taggedIn(
                (input.subgenres ?? []).slice(0, MAX_SUBGENRES),
                languageOf(context.event),
              ),
            }
          : {}),
        ...(input.narrators !== undefined
          ? { narrators: (input.narrators ?? []).slice(0, MAX_NARRATORS) }
          : {}),
        ...clearable('genre', input.genre),
        ...clearable('publisher', input.publisher),
        ...clearable('firstPublishedIn', input.firstPublishedIn),
        ...clearable('synopsis', input.synopsis),
        ...clearable('pageCount', input.pageCount),
        ...clearable('durationMinutes', input.durationMinutes),
        ...clearable('isbn13', input.isbn13),
        ...clearable('language', input.language),
        ...(input.series !== undefined
          ? {
              series: input.series
                ? {
                    name: input.series.name,
                    ...(input.series.volume != null ? { volume: input.series.volume } : {}),
                  }
                : undefined,
            }
          : {}),
      })
      return match(result)
        .with('not-found', () => notFound('Book not found'))
        .with('no-author', () => badUserInput('A book needs an author to start a new saga'))
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
      const result = await BookUseCase.setStatus(context.userId, args.id, args.status)
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
      const result = await BookUseCase.rate(context.userId, args.id, args.rating)
      return match(result)
        .with('not-found', () => notFound('Book not found'))
        .otherwise((book) => readBack(context.userId, book.id))
    },
  }),

  removeBookRating: t.field({
    type: BookType,
    description:
      'Take a rating back. The book stays read, with its reading dates: withdrawing ' +
      'a judgment is not saying the reading never happened.',
    args: { id: t.arg({ type: 'BookId', required: true }) },
    resolve: async (_root, args, context) => {
      const result = await BookUseCase.unrate(context.userId, args.id)
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
      const result = await BookUseCase.annotate(context.userId, args.id, args.note ?? undefined)
      return match(result)
        .with('not-found', () => notFound('Book not found'))
        .otherwise((book) => readBack(context.userId, book.id))
    },
  }),

  setBookFavorite: t.field({
    type: BookType,
    description: 'Keep a book close, or stop. Leaves the star rating alone.',
    args: {
      id: t.arg({ type: 'BookId', required: true }),
      favorite: t.arg.boolean({ required: true }),
    },
    resolve: async (_root, args, context) => {
      const result = await BookUseCase.setFavorite(context.userId, args.id, args.favorite)
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
      const result = await BookUseCase.setHidden(context.userId, args.id, args.hidden)
      return match(result)
        .with('not-found', () => notFound('Book not found'))
        .otherwise((book) => readBack(context.userId, book.id))
    },
  }),

  deleteBook: t.boolean({
    description: 'Remove a book from the library for good. Returns true when it was there.',
    args: { id: t.arg({ type: 'BookId', required: true }) },
    resolve: async (_root, args, context) => {
      const result = await BookUseCase.remove(context.userId, args.id)
      return match(result)
        .with('removed', () => true)
        .with('not-found', () => notFound('Book not found'))
        .exhaustive()
    },
  }),
}))
