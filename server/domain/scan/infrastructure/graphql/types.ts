import {
  BookFormatEnum,
  BookLanguageEnum,
  BookMediumEnum,
  GenreEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import type {
  DetectedBook,
  DetectedBox,
  ScannedSeries,
  ScanResult,
  TitleCandidate,
} from '~/domain/scan/types'
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
    media: t.field({
      type: [BookMediumEnum],
      description:
        'Where the photographed copy is held, when the cover said: DIGITAL for a ' +
        'cover shown on an e-reader. Empty when it did not; the app then proposes PRINT.',
      resolve: (result) => result.media ?? [],
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
    ownedCopy: t.field({
      type: BookType,
      nullable: true,
      description:
        'The record the reader already keeps of this book — the same title and first ' +
        'author, or the same ISBN — for the review to warn before a second copy is ' +
        'added. The earliest on the shelf when there are several. Null when the book ' +
        'is new to them, and when nothing was recognized.\n\n' +
        'A warning, not a refusal: `addBook` still adds a second edition on purpose.',
      resolve: (result, _args, { userId }) =>
        result.title === '' ? null : BookQuery.copyOf(userId, result),
    }),
  }),
})

export const TitleCandidateType = builder.objectRef<TitleCandidate>('TitleCandidate').implement({
  description:
    'One book a typed title may mean, offered for the reader to pick before the ' +
    'full lookup runs. Just enough to tell two books apart: hand `title` and the ' +
    'first author to `scanTitle` to build the record.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', resolve: (candidate) => candidate.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (candidate) => candidate.authors }),
    firstPublishedIn: t.field({
      type: 'Year',
      nullable: true,
      description: 'Year the work first appeared.',
      resolve: (candidate) => candidate.firstPublishedIn ?? null,
    }),
    seriesName: t.field({
      type: 'SeriesName',
      nullable: true,
      description: 'The saga it belongs to, null for a standalone book.',
      resolve: (candidate) => candidate.seriesName ?? null,
    }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      resolve: (candidate) => candidate.volume ?? null,
    }),
  }),
})

const DetectedBoxType = builder.objectRef<DetectedBox>('DetectedBox').implement({
  description:
    'Where a book sits in the photo, each side a fraction of it: `x` and `y` are the ' +
    'top-left corner, from 0 at the left and top edges to 1 at the right and bottom. ' +
    'Multiply by the size of the photo that was sent to crop the book out of it.',
  fields: (t) => ({
    x: t.exposeFloat('x'),
    y: t.exposeFloat('y'),
    width: t.exposeFloat('width'),
    height: t.exposeFloat('height'),
  }),
})

export const DetectedBookType = builder.objectRef<DetectedBook>('DetectedBook').implement({
  description:
    'One book found in a shelf photo, as printed on its spine or cover — nothing is ' +
    'looked up yet. The reader ticks the ones to keep, and `describeDetectedBook` ' +
    'builds the record of each.',
  fields: (t) => ({
    title: t.field({
      type: 'BookTitle',
      nullable: true,
      description: 'Null when the spine could not be read: the reader types it.',
      resolve: (book) => book.title ?? null,
    }),
    authors: t.field({ type: ['AuthorName'], resolve: (book) => book.authors }),
    publisher: t.field({
      type: 'Publisher',
      nullable: true,
      resolve: (book) => book.publisher ?? null,
    }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      resolve: (book) => book.language ?? null,
    }),
    format: t.field({
      type: BookFormatEnum,
      nullable: true,
      resolve: (book) => book.format ?? null,
    }),
    media: t.field({
      type: [BookMediumEnum],
      description: 'DIGITAL for a cover shown on a screen; empty when the photo did not say.',
      resolve: (book) => book.media ?? [],
    }),
    seriesName: t.field({
      type: 'SeriesName',
      nullable: true,
      description: 'Only when printed on the book.',
      resolve: (book) => book.seriesName ?? null,
    }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      resolve: (book) => book.volume ?? null,
    }),
    box: t.field({ type: DetectedBoxType, resolve: (book) => book.box }),
    owned: t.boolean({
      description:
        'The reader already has this story, in any edition — the same title by the ' +
        'same first author. Such a book comes unticked. Always false without a title.',
      resolve: (book) => book.owned,
    }),
  }),
})
