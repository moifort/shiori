import { match } from 'ts-pattern'
import {
  GoodreadsCoversType,
  GoodreadsImportOutcomeType,
  GoodreadsPreviewType,
} from '~/domain/goodreads/infrastructure/graphql/types'
import { GoodreadsUseCase } from '~/domain/goodreads/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput } from '~/domain/shared/graphql/errors'

/** A Goodreads export runs to about 600 bytes a book with its reviews: ten
 *  megabytes holds a library of over ten thousand. */
const MAX_EXPORT_BYTES = 10_000_000

const NOT_GOODREADS =
  'This file is not a Goodreads library export: it lacks the Book Id, Title, Author and ' +
  'Exclusive Shelf columns. The file to send is goodreads_library_export.csv.'
const EMPTY = 'This Goodreads export holds no book.'

const unreadable = (outcome: 'not-goodreads' | 'empty') =>
  match(outcome)
    .with('not-goodreads', () => badUserInput(NOT_GOODREADS))
    .with('empty', () => badUserInput(EMPTY))
    .exhaustive()

const GoodreadsToReadEnum = builder.enumType('GoodreadsToRead', {
  description: 'Where the to-read shelf goes.',
  values: {
    WISHLIST: { value: 'wishlist', description: 'The wishlist: books the reader would like.' },
    PILE: { value: 'pile', description: 'The pile: books the reader owns and has not read.' },
  } as const,
})

const GoodreadsChoicesInput = builder.inputType('GoodreadsChoicesInput', {
  description: 'What the reader decided on the preview.',
  fields: (t) => ({
    keys: t.stringList({ required: true, description: 'The keys of the rows to import.' }),
    toRead: t.field({ type: GoodreadsToReadEnum, required: true }),
    keepRatings: t.boolean({ required: true }),
    keepDates: t.boolean({ required: true }),
    keepReviews: t.boolean({ required: true, description: "Reviews become the book's note." }),
    sameBooks: t.stringList({
      required: true,
      description: 'Uncertain rows the reader said are the book they already hold.',
    }),
  }),
})

builder.mutationFields((t) => ({
  previewGoodreadsExport: t.field({
    type: GoodreadsPreviewType,
    description:
      'Read a Goodreads library export and answer with its books, each against the library ' +
      'it would join.\n\n' +
      'Nothing is saved and no paid service is called: this reads a file. A mutation for ' +
      'the size of its argument, not for what it does. Fails with `BAD_USER_INPUT` for a ' +
      'file above ten megabytes, one that is not a Goodreads export, or one with no book.',
    args: { csv: t.arg.string({ required: true, description: 'The export file, as text' }) },
    resolve: async (_root, { csv }, { userId }) => {
      if (csv.length > MAX_EXPORT_BYTES) return badUserInput('Export exceeds the 10 MB limit')
      const preview = await GoodreadsUseCase.preview(userId, csv)
      return typeof preview === 'string' ? unreadable(preview) : preview
    },
  }),

  importGoodreadsExport: t.field({
    type: GoodreadsImportOutcomeType,
    description:
      'Catalogue the rows the reader ticked, from a second read of the same file: the keys ' +
      'and choices say what was wanted, every stored field comes from the export.\n\n' +
      'New rows become books, or wishes when the to-read shelf goes to the wishlist; held ' +
      'rows complete their record with what it lacks. Running the same export twice adds ' +
      'nothing new. Covers are sought afterwards by `seekGoodreadsCovers`.',
    args: {
      csv: t.arg.string({ required: true, description: 'The same export file, as text' }),
      choices: t.arg({ type: GoodreadsChoicesInput, required: true }),
    },
    resolve: async (_root, { csv, choices }, { userId }) => {
      if (csv.length > MAX_EXPORT_BYTES) return badUserInput('Export exceeds the 10 MB limit')
      const outcome = await GoodreadsUseCase.importExport(userId, csv, choices)
      return typeof outcome === 'string' ? unreadable(outcome) : outcome
    },
  }),

  seekGoodreadsCovers: t.field({
    type: GoodreadsCoversType,
    description:
      'Look for the published covers of up to forty books the last import wrote, from free ' +
      'sources only (Amazon, Open Library, ePagine). Call again while `remaining` is above ' +
      'zero; a book no source has keeps the typeset stand-in.',
    resolve: (_root, _args, { userId }) => GoodreadsUseCase.seekCovers(userId),
  }),
}))
