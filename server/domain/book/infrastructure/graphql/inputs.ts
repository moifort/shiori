import {
  BookFormatEnum,
  GenreEnum,
  ReadingStatusEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import { VolumeKindEnum } from '~/domain/series/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'

/** The saga a scanned book belongs to, carried back from `scanBook` unchanged.
 *
 *  Only ever filled from a scan result. The app does not let a reader type this:
 *  membership is keyed to the shared catalogue, and a hand-typed saga would be
 *  one no catalogue knows, which would then never gather its other volumes. */
export const SeriesMembershipInput = builder.inputType('SeriesMembershipInput', {
  description: 'A book place in a saga, as `scanBook` resolved it. Pass it back unchanged.',
  fields: (t) => ({
    id: t.field({ type: 'SeriesId', required: true }),
    name: t.field({ type: 'SeriesName', required: true }),
    volume: t.field({ type: 'VolumeNumber', required: false }),
    kind: t.field({ type: VolumeKindEnum, required: true }),
  }),
})

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
    format: t.field({ type: BookFormatEnum, required: false, description: 'Defaults to BOOK.' }),
    publisher: t.field({ type: 'Publisher', required: false }),
    firstPublishedIn: t.field({ type: 'Year', required: false }),
    synopsis: t.field({ type: 'Synopsis', required: false }),
    genre: t.field({ type: GenreEnum, required: false }),
    subgenres: t.field({ type: ['Subgenre'], required: false, description: 'At most three.' }),
    pageCount: t.field({ type: 'PageCount', required: false }),
    narrators: t.field({
      type: ['NarratorName'],
      required: false,
      description: 'Who reads the recording, at most five. Only meaningful on an AUDIOBOOK.',
    }),
    isbn13: t.field({ type: 'Isbn13', required: false }),
    series: t.field({
      type: SeriesMembershipInput,
      required: false,
      description:
        'The saga this book belongs to, taken from a scan result. Omitted for a ' +
        'book typed by hand.',
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      required: false,
      description:
        'The publisher cover `scanBook` found by ISBN. Pass it back unchanged; ' +
        'omitted for a book typed by hand.',
    }),
    status: t.field({
      type: ReadingStatusEnum,
      required: false,
      description: 'Defaults to TO_READ, the only status true of every freshly catalogued book.',
    }),
    hidden: t.boolean({ required: false, description: 'Defaults to false.' }),
  }),
})

/** The fields a reader may correct after a scan got something wrong. Every field
 *  is optional and an omitted one is left untouched. Passing null clears an
 *  optional field; title and format cannot be cleared, and ignore a null. */
export const BookEditInput = builder.inputType('BookEditInput', {
  description:
    'Corrections to a book record. Omitted fields are left as they are; null clears ' +
    'a field (an empty list for authors, subgenres and narrators). Title and format ' +
    'ignore null.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', required: false }),
    authors: t.field({ type: ['AuthorName'], required: false }),
    format: t.field({ type: BookFormatEnum, required: false }),
    publisher: t.field({ type: 'Publisher', required: false }),
    firstPublishedIn: t.field({ type: 'Year', required: false }),
    synopsis: t.field({ type: 'Synopsis', required: false }),
    genre: t.field({ type: GenreEnum, required: false }),
    subgenres: t.field({ type: ['Subgenre'], required: false, description: 'At most three.' }),
    pageCount: t.field({ type: 'PageCount', required: false }),
    narrators: t.field({ type: ['NarratorName'], required: false, description: 'At most five.' }),
    isbn13: t.field({ type: 'Isbn13', required: false }),
  }),
})
