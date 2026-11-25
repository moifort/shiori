import {
  BookFormatEnum,
  BookLanguageEnum,
  BookMediumEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import type {
  GoodreadsImport,
  GoodreadsImportOutcome,
  GoodreadsPreview,
  GoodreadsPreviewRow,
} from '~/domain/goodreads/types'
import { builder } from '~/domain/shared/graphql/builder'

export const GoodreadsShelfEnum = builder.enumType('GoodreadsShelf', {
  description: 'The Goodreads shelf a book sits on: every book is on exactly one of these three.',
  values: {
    READ: { value: 'read' },
    CURRENTLY_READING: { value: 'currently-reading' },
    TO_READ: { value: 'to-read' },
  } as const,
})

export const GoodreadsVerdictEnum = builder.enumType('GoodreadsVerdict', {
  description: 'How a row of the export stands against the library it would join.',
  values: {
    NEW: { value: 'new', description: 'Not in the library: it becomes a book or a wish.' },
    HELD: {
      value: 'held',
      description: 'Already in the library: the record takes what it lacks — stars, date, review.',
    },
    UNCERTAIN: {
      value: 'uncertain',
      description:
        'Maybe a book the library holds — the same title by an author spelled otherwise, a ' +
        'volume titled after its saga. The reader says whether it is the same book.',
    },
  } as const,
})

const GoodreadsSeriesType = builder
  .objectRef<NonNullable<GoodreadsPreviewRow['series']>>('GoodreadsSeries')
  .implement({
    description: 'The saga a Goodreads title names: "Title (Saga, #2)".',
    fields: (t) => ({
      name: t.field({ type: 'SeriesName', resolve: (series) => series.name }),
      volume: t.field({
        type: 'VolumeNumber',
        nullable: true,
        resolve: (series) => series.volume ?? null,
      }),
    }),
  })

export const GoodreadsRowType = builder.objectRef<GoodreadsPreviewRow>('GoodreadsRow').implement({
  description:
    'One book of a Goodreads library export, read and checked, before anything is saved.',
  fields: (t) => ({
    key: t.exposeString('key', {
      description: 'What to tick: pass the wanted ones to `importGoodreadsExport`.',
    }),
    title: t.field({ type: 'BookTitle', resolve: (row) => row.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (row) => row.authors }),
    series: t.field({ type: GoodreadsSeriesType, nullable: true, resolve: (row) => row.series }),
    isbn13: t.field({ type: 'Isbn13', nullable: true, resolve: (row) => row.isbn13 ?? null }),
    format: t.field({ type: BookFormatEnum, resolve: (row) => row.format }),
    media: t.field({ type: [BookMediumEnum], resolve: (row) => row.media }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      description: 'Read off the ISBN registration group, when it says.',
      resolve: (row) => row.language ?? null,
    }),
    rating: t.field({ type: 'StarRating', nullable: true, resolve: (row) => row.rating ?? null }),
    readOn: t.field({ type: 'DateTime', nullable: true, resolve: (row) => row.readOn ?? null }),
    shelf: t.field({ type: GoodreadsShelfEnum, resolve: (row) => row.shelf }),
    dropped: t.exposeBoolean('dropped', {
      description: 'On a shelf of the reader\'s own saying they gave it up: "dnf", "abandoned".',
    }),
    hasReview: t.boolean({ resolve: (row) => row.review !== undefined }),
    verdict: t.field({ type: GoodreadsVerdictEnum, resolve: (row) => row.verdict }),
    heldBookId: t.field({
      type: 'BookId',
      nullable: true,
      description: 'The record a held or uncertain row would complete.',
      resolve: (row) => row.heldBookId ?? null,
    }),
    heldTitle: t.field({
      type: 'BookTitle',
      nullable: true,
      resolve: (row) => row.heldTitle ?? null,
    }),
    heldCoverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      resolve: (row) => row.heldCoverUrl ?? null,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      description:
        'An Open Library address guessed from the ISBN, never fetched: it answers 404 when ' +
        'there is no cover, and the app then draws its typeset stand-in.',
      resolve: (row) => row.coverGuess ?? null,
    }),
  }),
})

const GoodreadsShelvesType = builder
  .objectRef<GoodreadsPreview['shelves']>('GoodreadsShelves')
  .implement({
    description:
      'How many books each shelf holds; `dropped` is counted apart from the other three.',
    fields: (t) => ({
      read: t.exposeInt('read'),
      reading: t.exposeInt('reading'),
      toRead: t.exposeInt('toRead'),
      dropped: t.exposeInt('dropped'),
    }),
  })

export const GoodreadsPreviewType = builder
  .objectRef<GoodreadsPreview>('GoodreadsPreview')
  .implement({
    description: 'What a Goodreads export holds, against the library it would join.',
    fields: (t) => ({
      rows: t.field({ type: [GoodreadsRowType], resolve: (preview) => preview.rows }),
      shelves: t.field({ type: GoodreadsShelvesType, resolve: (preview) => preview.shelves }),
      rated: t.exposeInt('rated', { description: "Books carrying the reader's stars." }),
      dated: t.exposeInt('dated', { description: 'Books carrying a reading date.' }),
      reviewed: t.exposeInt('reviewed', { description: 'Books carrying a review.' }),
    }),
  })

export const GoodreadsImportOutcomeType = builder
  .objectRef<GoodreadsImportOutcome>('GoodreadsImportOutcome')
  .implement({
    description: 'What an import wrote.',
    fields: (t) => ({
      imported: t.exposeInt('imported', { description: 'Books created.' }),
      completed: t.exposeInt('completed', {
        description: 'Books already held that took the Goodreads stars, date or review.',
      }),
      wished: t.exposeInt('wished', { description: 'Wishes created from the to-read shelf.' }),
      pendingCovers: t.exposeInt('pendingCovers', {
        description: 'Books whose cover `seekGoodreadsCovers` is still to look for.',
      }),
    }),
  })

export const GoodreadsCoversType = builder
  .objectRef<{ remaining: number; found: number }>('GoodreadsCovers')
  .implement({
    description: 'One pass of the cover search after an import.',
    fields: (t) => ({
      found: t.exposeInt('found', { description: 'Covers written by this pass.' }),
      remaining: t.exposeInt('remaining', {
        description: 'Books still waiting: call again while it is above zero.',
      }),
    }),
  })

export const GoodreadsImportType = builder.objectRef<GoodreadsImport>('GoodreadsImport').implement({
  description: "The reader's last Goodreads import, for the settings page.",
  fields: (t) => ({
    importedAt: t.field({ type: 'DateTime', resolve: (record) => record.importedAt }),
    imported: t.exposeInt('imported'),
    completed: t.exposeInt('completed'),
    wished: t.exposeInt('wished'),
    pendingCovers: t.int({ resolve: (record) => record.pendingCovers.length }),
    withoutCover: t.exposeInt('withoutCover', {
      description: "Books no source had a cover for: they keep the app's typeset stand-in.",
    }),
  }),
})
