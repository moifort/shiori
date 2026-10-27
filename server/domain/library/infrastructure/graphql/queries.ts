import { FollowedAuthorType } from '~/domain/author/infrastructure/graphql/queries'
import { AwardMentionType } from '~/domain/award/infrastructure/graphql/types'
import { BookFormatEnum, GenreEnum, heldAs } from '~/domain/book/infrastructure/graphql/enums'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import type { BookView } from '~/domain/book/types'
import type {
  GenreShelf,
  LibraryShelves,
  PILE_SECTIONS,
  PilePick,
  PileRequest,
  PileSection,
} from '~/domain/library/types'
import { LibraryUseCase } from '~/domain/library/use-case'
import { FollowedNarratorType } from '~/domain/narrator/infrastructure/graphql/queries'
import { FollowedSeriesType } from '~/domain/series/infrastructure/graphql/queries'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'
import { Count } from '~/domain/shared/primitives'

const GenreShelfType = builder
  .objectRef<GenreShelf & { cover?: BookView }>('GenreShelf')
  .implement({
    description: 'A genre of the reader library, as the tile of "Par genre" draws it.',
    fields: (t) => ({
      genre: t.field({ type: GenreEnum, resolve: (shelf) => shelf.genre }),
      count: t.field({
        type: 'Count',
        description: 'Books of that genre the view keeps.',
        resolve: (shelf) => Count(shelf.count),
      }),
      cover: t.field({
        type: BookType,
        nullable: true,
        description:
          'The book shelved last of that genre that has a cover, drawn tilted in the ' +
          'tile. Null when none has one.',
        resolve: (shelf) => shelf.cover ?? null,
      }),
    }),
  })

const LibraryShelvesType = builder.objectRef<LibraryShelves>('LibraryShelves')

LibraryShelvesType.implement({
  description:
    'The Library tab entry screen: its pills and its rails, in the view asked. Every ' +
    'field reads the one library scan the request shares: asking for all of them ' +
    'costs one scan, plus the catalogues of the series and the authors drawn.',
  fields: (t) => ({
    formats: t.field({
      type: [BookFormatEnum],
      description:
        'The formats the library holds — under a genre, those of its books — in the ' +
        'order the pills list them. Never narrowed by `format` itself.',
      resolve: (shelves) => LibraryUseCase.formats(shelves.userId, shelves.view),
    }),
    recent: t.field({
      type: [BookType],
      description:
        '"Récemment": every book, newest on `shelvedAt` first. Twenty books at most, covers signed for those alone.',
      resolve: (shelves) => LibraryUseCase.rail(shelves.userId, shelves.view, 'recent'),
    }),
    toRead: t.field({
      type: [BookType],
      description:
        '"Pile à lire": the pile, the book added last first. Twenty books at most, covers signed for those alone.',
      resolve: (shelves) => LibraryUseCase.rail(shelves.userId, shelves.view, 'toRead'),
    }),
    readRecently: t.field({
      type: [BookType],
      description:
        '"Lus récemment": the books read, the one finished last first. Twenty books at most, covers signed for those alone.',
      resolve: (shelves) => LibraryUseCase.rail(shelves.userId, shelves.view, 'readRecently'),
    }),
    favorites: t.field({
      type: [BookType],
      description:
        '"Coups de cœur": the books hearted or rated four and a half stars or more, and the unrated ' +
        'volumes of a saga hearted or rated four and a half stars or more, newest on `shelvedAt` ' +
        'first. Twenty books at most, covers signed for those alone.',
      args: {
        excludeLovedSeries: t.arg.boolean({
          required: false,
          description:
            'Leave out the volumes of the sagas the reader hearted, which `lovedSeries` ' +
            'draws whole.',
          deprecationReason: 'The rail draws the hearted books alone, never a saga in their place.',
        }),
      },
      resolve: (shelves, args) =>
        args.excludeLovedSeries
          ? LibraryUseCase.favoritesBesideSeries(shelves.userId, shelves.view)
          : LibraryUseCase.rail(shelves.userId, shelves.view, 'favorites'),
    }),
    lovedSeries: t.field({
      type: [FollowedSeriesType],
      description:
        'The sagas of "Coups de cœur": those the reader hearted holding a book of the ' +
        'view, the one shelved last first, set aside or not. Reads those catalogues ' +
        'in one getAll.',
      resolve: (shelves) => LibraryUseCase.lovedSeries(shelves.userId, shelves.view),
    }),
    hasDropped: t.boolean({
      description: 'Whether the view holds a book given up on: the "Abandonnés" row.',
      resolve: (shelves) => LibraryUseCase.hasDropped(shelves.userId, shelves.view),
    }),
    genres: t.field({
      type: [GenreShelfType],
      description: 'The genres of the books the view keeps, the most held first.',
      resolve: (shelves) => LibraryUseCase.genres(shelves.userId, shelves.view),
    }),
    subgenres: t.field({
      type: ['Subgenre'],
      description:
        'Under a `genre`, its subgenres the reader used, the most used first, in the ' +
        'language of `Accept-Language`: the pills of the genre page. Empty otherwise.',
      resolve: (shelves, _args, { event }) =>
        LibraryUseCase.subgenres(shelves.userId, shelves.view, languageOf(event)),
    }),
    series: t.field({
      type: [FollowedSeriesType],
      description:
        'The sagas holding a book of the view, the one shelved last first, a dozen at ' +
        'most; the ones set aside left out. Reads those catalogues in one getAll.',
      resolve: (shelves) => LibraryUseCase.series(shelves.userId, shelves.view),
    }),
    authors: t.field({
      type: [FollowedAuthorType],
      description:
        'The authors of the view books, the one shelved last first, a dozen at most, ' +
        'with their portraits: their catalogues in one getAll.',
      resolve: (shelves) => LibraryUseCase.authors(shelves.userId, shelves.view),
    }),
    narrators: t.field({
      type: [FollowedNarratorType],
      description:
        'Who reads the view’s recordings, the one shelved last first, a dozen at most, ' +
        'with their faces: their entries in one getAll. Empty when the view holds no ' +
        'audiobook.',
      resolve: (shelves) => LibraryUseCase.narrators(shelves.userId, shelves.view),
    }),
  }),
})

const PileSectionKindEnum = builder.enumType('PileSectionKind', {
  description: 'Why the pile offers a book: one section each, in the order the screen draws them.',
  values: {
    TO_FINISH: {
      value: 'to-finish',
      description:
        '"À finir": the books in progress, the one begun longest ago first. Before opening a ' +
        'new book, the ones waiting to be finished.',
    },
    NEXT_VOLUME: {
      value: 'next-volume',
      description:
        '"La suite": in each saga the reader read a volume of, the first main volume of the ' +
        'pile, the saga read last first.',
    },
    RECOMMENDED: {
      value: 'recommended',
      description: '"Recommandés": the books the reader recorded someone recommending.',
    },
    FAVORITE_AUTHORS: {
      value: 'favorite-authors',
      description:
        '"Auteurs préférés": books by an author the reader rated a book of four stars or ' +
        'more, or hearted.',
    },
    FAVORITE_NARRATORS: {
      value: 'favorite-narrators',
      description:
        '"Narrateurs préférés": recordings read by a voice the reader hearted — not one ' +
        'whose recordings they rated: a narrator reads every kind of story.',
    },
    AWARDED: {
      value: 'awarded',
      description:
        '"Primés": books that won one of Découvrir\'s awards, matched on the title and the ' +
        'author. `award` says which.',
    },
    NEW_AUTHORS: {
      value: 'new-authors',
      description: '"Nouveaux auteurs": books by authors the reader has read nothing of yet.',
    },
  } satisfies Record<string, { value: (typeof PILE_SECTIONS)[number]; description: string }>,
})

const PilePickType = builder.objectRef<PilePick<BookView>>('PilePick').implement({
  description: 'A book a section of the pile offers.',
  fields: (t) => ({
    book: t.field({ type: BookType, resolve: (pick) => pick.book }),
    award: t.field({
      type: AwardMentionType,
      nullable: true,
      description: 'In "Primés", the latest prize the book won. Null in every other section.',
      resolve: (pick) => pick.award ?? null,
    }),
  }),
})

const PileSectionType = builder.objectRef<PileSection<BookView>>('PileSection').implement({
  description: 'One section of the pile: never empty, fifteen books at most.',
  fields: (t) => ({
    kind: t.field({ type: PileSectionKindEnum, resolve: (section) => section.kind }),
    picks: t.field({
      type: [PilePickType],
      description: 'Its books, in the order the section gives them.',
      resolve: (section) => section.picks,
    }),
  }),
})

const PileType = builder.objectRef<PileRequest>('Pile').implement({
  description:
    'The pile cut into the reasons to read its books, for choosing the next one. Every ' +
    'field reads the one library scan the request shares; the sections read the award ' +
    'winners Découvrir keeps too. Nothing calls a paid service.',
  fields: (t) => ({
    formats: t.field({
      type: [BookFormatEnum],
      description:
        'The formats of the pile and of the books in progress — under a genre, those of ' +
        'its books — in the order the pills list them. Never narrowed by `format` itself.',
      resolve: (pile) => LibraryUseCase.pileFormats(pile.userId, pile.view),
    }),
    sections: t.field({
      type: [PileSectionType],
      description:
        'The sections in the view, in the order of `PileSectionKind`, the empty ones left ' +
        'out. A book may sit in several. The whole pile is `libraryPage(status: TO_READ)`.',
      resolve: (pile) => LibraryUseCase.pileSections(pile.userId, pile.view),
    }),
  }),
})

builder.queryFields((t) => ({
  pile: t.field({
    type: PileType,
    description:
      'The pile in sections, narrowed to a format pill, or to a genre and one of its ' +
      'subgenres when opened from a genre page.',
    args: {
      format: t.arg({ type: BookFormatEnum, required: false, description: 'The format pill' }),
      genre: t.arg({ type: GenreEnum, required: false, description: 'A genre page' }),
      subgenre: t.arg({
        type: 'Subgenre',
        required: false,
        description: 'A subgenre pill of the genre page, matched whatever its case',
      }),
    },
    resolve: (_root, args, { userId }) => ({
      userId,
      view: {
        format: heldAs(args.format).format,
        genre: args.genre ?? undefined,
        subgenre: args.subgenre ?? undefined,
      },
    }),
  }),
  libraryShelves: t.field({
    type: LibraryShelvesType,
    description:
      'The Library tab entry screen, narrowed to a format pill, or to a genre and one ' +
      'of its subgenres on a genre page. Each rail opens on `libraryPage` with the ' +
      'same filter.',
    args: {
      format: t.arg({ type: BookFormatEnum, required: false, description: 'The format pill' }),
      genre: t.arg({ type: GenreEnum, required: false, description: 'A genre page' }),
      subgenre: t.arg({
        type: 'Subgenre',
        required: false,
        description: 'A subgenre pill of the genre page, matched whatever its case',
      }),
    },
    resolve: (_root, args, { userId }) => ({
      userId,
      view: {
        format: heldAs(args.format).format,
        genre: args.genre ?? undefined,
        subgenre: args.subgenre ?? undefined,
      },
    }),
  }),
}))
