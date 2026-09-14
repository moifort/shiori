import { ReadingStatusEnum } from '~/domain/book/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'

/** What a book can be created with by hand, with no photo and no AI call. Only a
 *  title is required: a book added from a half-remembered recommendation is still
 *  a book, and demanding an author would push the reader back to a notes app. */
export const NewBookInput = builder.inputType('NewBookInput', {
  description:
    'A book catalogued without a scan — typed by hand, or taken from a series ' +
    'catalogue. Consumes no scan credit.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', required: true }),
    authors: t.field({ type: ['AuthorName'], required: false }),
    publisher: t.field({ type: 'Publisher', required: false }),
    firstPublishedIn: t.field({ type: 'Year', required: false }),
    synopsis: t.field({ type: 'Synopsis', required: false }),
    genres: t.field({ type: ['Genre'], required: false }),
    pageCount: t.field({ type: 'PageCount', required: false }),
    isbn13: t.field({ type: 'Isbn13', required: false }),
    status: t.field({
      type: ReadingStatusEnum,
      required: false,
      description: 'Defaults to TO_READ, the only status true of every freshly catalogued book.',
    }),
    hidden: t.boolean({ required: false, description: 'Defaults to false.' }),
  }),
})

/** The fields a reader may correct after a scan got something wrong. Every field
 *  is optional and an omitted one is left untouched. */
export const BookEditInput = builder.inputType('BookEditInput', {
  description: 'Corrections to a book record. Omitted fields are left as they are.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', required: false }),
    authors: t.field({ type: ['AuthorName'], required: false }),
    publisher: t.field({ type: 'Publisher', required: false }),
    firstPublishedIn: t.field({ type: 'Year', required: false }),
    synopsis: t.field({ type: 'Synopsis', required: false }),
    genres: t.field({ type: ['Genre'], required: false }),
    pageCount: t.field({ type: 'PageCount', required: false }),
    isbn13: t.field({ type: 'Isbn13', required: false }),
  }),
})
