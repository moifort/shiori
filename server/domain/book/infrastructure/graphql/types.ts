import {
  BookFormatEnum,
  BookLanguageEnum,
  GenreEnum,
  ReadingStatusEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import type { BookView, LibrarySection, SeriesMembership } from '~/domain/book/types'
import { VolumeKindEnum } from '~/domain/series/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'

const SeriesMembershipType = builder.objectRef<SeriesMembership>('SeriesMembership').implement({
  description:
    'A book place in a saga, carried on the book itself.\n\n' +
    'The series name is denormalized here on purpose: grouping a 300-book ' +
    'library into sections must not read one catalogue document per row.',
  fields: (t) => ({
    id: t.field({ type: 'SeriesId', resolve: (membership) => membership.id }),
    name: t.field({ type: 'SeriesName', resolve: (membership) => membership.name }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      description: 'Null for a spin-off or companion, which sit outside the numbering.',
      resolve: (membership) => membership.volume ?? null,
    }),
    kind: t.field({ type: VolumeKindEnum, resolve: (membership) => membership.kind }),
  }),
})

export const BookType = builder.objectRef<BookView>('Book').implement({
  description:
    'A book as one reader holds it.\n\n' +
    'Private and owned by exactly one reader: two people who scan the same novel ' +
    'keep two independent records. Public facts (title, synopsis, series) and ' +
    'personal judgment (status, rating, note) sit side by side, because the ' +
    'record belongs to the reader rather than to the world.',
  fields: (t) => ({
    id: t.field({ type: 'BookId', resolve: (book) => book.id }),
    title: t.field({ type: 'BookTitle', resolve: (book) => book.title }),
    authors: t.field({
      type: ['AuthorName'],
      description: 'Empty when nothing legible was found, never null.',
      resolve: (book) => book.authors,
    }),
    format: t.field({ type: BookFormatEnum, resolve: (book) => book.format }),
    publisher: t.field({
      type: 'Publisher',
      nullable: true,
      resolve: (book) => book.publisher ?? null,
    }),
    firstPublishedIn: t.field({
      type: 'Year',
      nullable: true,
      description: 'Year the work first appeared, not the year of this edition.',
      resolve: (book) => book.firstPublishedIn ?? null,
    }),
    synopsis: t.field({
      type: 'Synopsis',
      nullable: true,
      resolve: (book) => book.synopsis ?? null,
    }),
    genre: t.field({
      type: GenreEnum,
      nullable: true,
      description: 'Null for a book added by hand, or when the reader cleared it.',
      resolve: (book) => book.genre ?? null,
    }),
    subgenres: t.field({
      type: ['Subgenre'],
      description: 'Zero to three free labels refining the genre. Empty, never null.',
      resolve: (book) => book.subgenres,
    }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      description:
        'The language of this edition, read off the cover at scan time. Null on ' +
        'a book catalogued before the scan started reading it, and on any edition ' +
        'in a language the closed list does not carry.',
      resolve: (book) => book.language ?? null,
    }),
    durationMinutes: t.int({
      nullable: true,
      description:
        "An audiobook's running time in whole minutes. Null on anything else, " +
        'and null on an audiobook no import ever timed — a scanned cover does ' +
        'not say how long the recording is.',
      resolve: (book) => book.durationMinutes ?? null,
    }),
    narrators: t.field({
      type: ['NarratorName'],
      description:
        'Who reads the recording, at most five. Empty on anything but an ' +
        'audiobook, and empty on an audiobook no import ever named.',
      resolve: (book) => book.narrators ?? [],
    }),
    pageCount: t.field({
      type: 'PageCount',
      nullable: true,
      resolve: (book) => book.pageCount ?? null,
    }),
    isbn13: t.field({ type: 'Isbn13', nullable: true, resolve: (book) => book.isbn13 ?? null }),
    series: t.field({
      type: SeriesMembershipType,
      nullable: true,
      description: 'Null for a standalone book.',
      resolve: (book) => book.series ?? null,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      description:
        'The cover to draw: the reader own photo when there is one, otherwise the ' +
        'publisher cover found by ISBN at scan time. Null when neither exists, and ' +
        'the app draws a typographic placeholder — as it must when the URL fails to ' +
        'load, since a published cover can disappear from its source.',
      resolve: (book) => book.coverUrl ?? null,
    }),
    status: t.field({ type: ReadingStatusEnum, resolve: (book) => book.status }),
    rating: t.field({
      type: 'StarRating',
      nullable: true,
      description: 'One to five whole stars. Null until the reader rates it.',
      resolve: (book) => book.rating ?? null,
    }),
    note: t.field({
      type: 'ReadingNote',
      nullable: true,
      resolve: (book) => book.note ?? null,
    }),
    hidden: t.boolean({
      description: 'Excluded from any shared view. Sharing itself is not built yet.',
      resolve: (book) => book.hidden,
    }),
    addedAt: t.field({ type: 'DateTime', resolve: (book) => book.addedAt }),
    startedAt: t.field({
      type: 'DateTime',
      nullable: true,
      resolve: (book) => book.startedAt ?? null,
    }),
    finishedAt: t.field({
      type: 'DateTime',
      nullable: true,
      resolve: (book) => book.finishedAt ?? null,
    }),
  }),
})

export const LibrarySectionType = builder.objectRef<LibrarySection>('LibrarySection').implement({
  description:
    'One heading of the library list.\n\n' +
    'A section holds only books the reader owns: the catalogue never adds a row ' +
    'here. A saga gets its own section from the first volume owned, so a book ' +
    'never migrates between sections when an unrelated one is added.\n\n' +
    'A saga held in two languages makes two sections, one per language. They ' +
    'share a `seriesId` and differ by `language`, so a client keying rows on the ' +
    'saga alone must key on the pair instead.',
  fields: (t) => ({
    series: t.field({
      type: 'SeriesName',
      nullable: true,
      description: 'Null on the trailing shelf, which gathers the standalone books.',
      resolve: (section) => section.series?.name ?? null,
    }),
    seriesId: t.field({
      type: 'SeriesId',
      nullable: true,
      resolve: (section) => section.series?.id ?? null,
    }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      description:
        'The language its volumes are in. Null on the standalone shelf, and null ' +
        'on a saga whose volumes carry no recorded language.',
      resolve: (section) => section.series?.language ?? null,
    }),
    books: t.field({
      type: [BookType],
      description: 'Ordered along the spine, then related works; by title on the shelf.',
      resolve: (section) => section.books,
    }),
  }),
})
