import {
  BookFormatEnum,
  BookLanguageEnum,
  GenreEnum,
  ReadingStatusEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import { VolumeKindEnum } from '~/domain/series/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'

/** The saga a scanned book belongs to, carried back from `scanBook` unchanged.
 *
 *  Only ever filled from a scan result. A reader who names a saga by hand does it
 *  through `SeriesPlacementInput`, which keys it the way a scan would: a typed
 *  key would be one no catalogue knows, and would never gather other volumes. */
export const SeriesMembershipInput = builder.inputType('SeriesMembershipInput', {
  description: 'A book place in a saga, as `scanBook` resolved it. Pass it back unchanged.',
  fields: (t) => ({
    id: t.field({ type: 'SeriesId', required: true }),
    name: t.field({ type: 'SeriesName', required: true }),
    volume: t.field({ type: 'VolumeNumber', required: false }),
    kind: t.field({ type: VolumeKindEnum, required: true }),
  }),
})

/** A saga named by hand in the edit form, for a book the scan did not place. */
export const SeriesPlacementInput = builder.inputType('SeriesPlacementInput', {
  description:
    'The saga a reader puts a book in by hand. The saga is found from the name, never ' +
    'typed as a key: the one the reader holds under the key a scan would give it ' +
    '(name and first author), else one they hold under the same name folded — ' +
    'accents, punctuation and a leading article aside — else a new saga under that key.',
  fields: (t) => ({
    name: t.field({ type: 'SeriesName', required: true }),
    volume: t.field({
      type: 'VolumeNumber',
      required: false,
      description: 'The volume number. Absent for a volume with no number.',
    }),
  }),
})

/** Who recommended a book, as the reader records it from the book's sheet. */
export const RecommendationInput = builder.inputType('RecommendationInput', {
  description:
    'Who recommended a book and what they said of it. Both fields are optional; ' +
    'leaving both out clears the recommendation.',
  fields: (t) => ({
    recommenderName: t.field({
      type: 'PersonName',
      required: false,
      description: 'Who recommended the book, typically picked from the contacts.',
    }),
    comment: t.field({ type: 'RecommendationComment', required: false }),
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
    subgenres: t.field({
      type: ['Subgenre'],
      required: false,
      description: 'At most three, most representative first.',
    }),
    pageCount: t.field({ type: 'PageCount', required: false }),
    narrators: t.field({
      type: ['NarratorName'],
      required: false,
      description: 'Who reads the recording, at most five. Only meaningful on an AUDIOBOOK.',
    }),
    language: t.field({
      type: BookLanguageEnum,
      required: false,
      description: 'The language of this edition, taken from a scan result.',
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
    subgenres: t.field({
      type: ['Subgenre'],
      required: false,
      description: 'At most three, most representative first.',
    }),
    pageCount: t.field({ type: 'PageCount', required: false }),
    durationMinutes: t.field({
      type: 'ListeningMinutes',
      required: false,
      description: 'The running time of an audiobook, in minutes.',
    }),
    narrators: t.field({ type: ['NarratorName'], required: false, description: 'At most five.' }),
    language: t.field({ type: BookLanguageEnum, required: false }),
    isbn13: t.field({ type: 'Isbn13', required: false }),
    series: t.field({
      type: SeriesPlacementInput,
      required: false,
      description:
        'Put the book in a saga, or move it to another. Null takes it out of its saga. ' +
        'A book with no author can only join a saga the reader already holds.',
    }),
  }),
})
