import {
  BookFormatEnum,
  BookLanguageEnum,
  GenreEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import type { ScannedSeries, ScanResult } from '~/domain/scan/types'
import { VolumeKindEnum } from '~/domain/series/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'

const ScannedSeriesType = builder.objectRef<ScannedSeries>('ScannedSeries').implement({
  description:
    'The saga the scanned book belongs to, as the enrichment step resolved it.\n\n' +
    'Absent for a standalone book, which is most of them. Found by the web search ' +
    'rather than read off the cover: a great many novels belong to a cycle the ' +
    'cover never mentions.',
  fields: (t) => ({
    id: t.field({
      type: 'SeriesId',
      description:
        'Hand this back to `addBook` unchanged so the book joins the very ' +
        'catalogue this scan built.',
      resolve: (series) => series.id,
    }),
    name: t.field({ type: 'SeriesName', resolve: (series) => series.name }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      resolve: (series) => series.volume ?? null,
    }),
    kind: t.field({ type: VolumeKindEnum, resolve: (series) => series.kind }),
  }),
})

export const ScanResultType = builder.objectRef<ScanResult>('ScanResult').implement({
  description:
    'What the model read on a cover, after enrichment. Nothing is saved yet: the ' +
    'reader reviews this and decides.\n\n' +
    'Check `recognized` first. False means no book was identified — a photo of ' +
    'something that is not a cover — and every other field is empty. It is an ' +
    'ordinary outcome, not an error, and it costs no scan.\n\n' +
    'Optional fields are absent rather than guessed. A field the model was unsure ' +
    'of is dropped on the way through: an invented ISBN or a page count of zero ' +
    'is worse than nothing, because it would be trusted later.',
  fields: (t) => ({
    recognized: t.boolean({ resolve: (result) => result.recognized }),
    title: t.field({
      type: 'BookTitle',
      nullable: true,
      description: 'Null when nothing was recognized.',
      resolve: (result) => (result.title === '' ? null : result.title),
    }),
    authors: t.field({ type: ['AuthorName'], resolve: (result) => result.authors }),
    format: t.field({
      type: BookFormatEnum,
      nullable: true,
      description: 'Null when the cover did not say. The app then proposes BOOK.',
      resolve: (result) => result.format ?? null,
    }),
    publisher: t.field({
      type: 'Publisher',
      nullable: true,
      resolve: (result) => result.publisher ?? null,
    }),
    firstPublishedIn: t.field({
      type: 'Year',
      nullable: true,
      description: 'Year the work first appeared, not the year of this edition.',
      resolve: (result) => result.firstPublishedIn ?? null,
    }),
    synopsis: t.field({
      type: 'Synopsis',
      nullable: true,
      resolve: (result) => result.synopsis ?? null,
    }),
    genre: t.field({
      type: GenreEnum,
      nullable: true,
      description: 'Null when the model could not classify the book.',
      resolve: (result) => result.genre ?? null,
    }),
    subgenres: t.field({ type: ['Subgenre'], resolve: (result) => result.subgenres ?? [] }),
    pageCount: t.field({
      type: 'PageCount',
      nullable: true,
      resolve: (result) => result.pageCount ?? null,
    }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      description:
        'The language of the photographed edition, read off the cover — the object ' +
        'on the shelf, not the language the work was written in. Null when the ' +
        'cover does not settle it. Hand it back to `addBook` unchanged.',
      resolve: (result) => result.language ?? null,
    }),
    isbn13: t.field({ type: 'Isbn13', nullable: true, resolve: (result) => result.isbn13 ?? null }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      description:
        'The publisher cover, found by ISBN and checked to exist. Null without an ' +
        'ISBN or when none was found. Hand it back to `addBook` unchanged.',
      resolve: (result) => result.coverUrl ?? null,
    }),
    series: t.field({
      type: ScannedSeriesType,
      nullable: true,
      resolve: (result) => result.series ?? null,
    }),
  }),
})
