import {
  BookFormatEnum,
  BookLanguageEnum,
  GenreEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import type {
  Discover,
  FriendFavorite,
  LovedShelf,
  Release,
  Suggestion,
} from '~/domain/discover/types'
import { AlertKindEnum } from '~/domain/notification/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'

export const SuggestionType = builder.objectRef<Suggestion>('Suggestion').implement({
  description:
    'A book the Découvrir tab proposes, with the one line that says why. Never a ' +
    'book the reader owns or dismissed.',
  fields: (t) => ({
    key: t.string({
      description:
        'The title and first author folded: what `dismissSuggestion` and `addSuggestion` name.',
      resolve: (item) => item.key,
    }),
    title: t.field({ type: 'BookTitle', resolve: (item) => item.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (item) => item.authors }),
    firstPublishedIn: t.field({
      type: 'Year',
      nullable: true,
      resolve: (item) => item.firstPublishedIn ?? null,
    }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      resolve: (item) => item.language ?? null,
    }),
    format: t.field({ type: BookFormatEnum, resolve: (item) => item.format }),
    genre: t.field({ type: GenreEnum, nullable: true, resolve: (item) => item.genre ?? null }),
    seriesName: t.field({
      type: 'SeriesName',
      nullable: true,
      resolve: (item) => item.series?.name ?? null,
    }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      resolve: (item) => item.series?.volume ?? null,
    }),
    synopsis: t.field({
      type: 'Synopsis',
      nullable: true,
      resolve: (item) => item.synopsis ?? null,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      resolve: (item) => item.coverUrl ?? null,
    }),
    reason: t.string({
      description: 'Why this book, for this reader, in one line of their language.',
      resolve: (item) => item.reason,
    }),
    award: t.string({
      nullable: true,
      description: 'The prize it won, e.g. "Hugo 2024".',
      resolve: (item) => item.award ?? null,
    }),
    publicRating: t.float({
      nullable: true,
      description: 'What readers worldwide rate it, out of five, one decimal.',
      resolve: (item) => item.publicRating ?? null,
    }),
    ratingCount: t.int({
      nullable: true,
      description: 'How many readers rated it.',
      resolve: (item) => item.ratingCount ?? null,
    }),
    releaseDate: t.string({
      nullable: true,
      description:
        'When it comes out, as precisely as announced: `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.',
      resolve: (item) => item.releaseDate ?? null,
    }),
  }),
})

export const ReleaseType = builder.objectRef<Release>('Release').implement({
  description: 'A book coming out that the reader has a reason to care about.',
  fields: (t) => ({
    key: t.string({
      description: 'What `dismissSuggestion` names to hide it.',
      resolve: (release) => release.key,
    }),
    suggestion: t.field({
      type: SuggestionType,
      description: 'The book itself; its key is what `addSuggestion` names.',
      resolve: (release) => release,
    }),
    kind: t.field({
      type: AlertKindEnum,
      description: 'Which alert it would fire: a saga volume, a translation, a recording…',
      resolve: (release) => release.kind,
    }),
    date: t.string({
      description: '`YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Only a day ever fires an alert.',
      resolve: (release) => release.date,
    }),
  }),
})

const LovedShelfType = builder.objectRef<LovedShelf>('LovedShelf').implement({
  description: '"Parce que vous avez aimé X": books in the vein of one the reader loved.',
  fields: (t) => ({
    anchor: t.field({ type: 'BookTitle', resolve: (shelf) => shelf.anchor }),
    items: t.field({ type: [SuggestionType], resolve: (shelf) => shelf.items }),
  }),
})

const FriendFavoriteType = builder.objectRef<FriendFavorite>('FriendFavorite').implement({
  description:
    'A book a friend hearted that the reader does not own. Opens as the friend’s ' +
    'copy, through `friendBook(userId, bookId)`.',
  fields: (t) => ({
    key: t.exposeString('key'),
    friendId: t.field({ type: 'UserId', resolve: (favorite) => favorite.friendId }),
    bookId: t.field({ type: 'BookId', resolve: (favorite) => favorite.bookId }),
    friendNames: t.stringList({
      description: 'Every friend who hearted it, first names.',
      resolve: (favorite) => favorite.friendNames,
    }),
    title: t.field({ type: 'BookTitle', resolve: (favorite) => favorite.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (favorite) => favorite.authors }),
    format: t.field({ type: BookFormatEnum, resolve: (favorite) => favorite.format }),
    seriesName: t.field({
      type: 'SeriesName',
      nullable: true,
      resolve: (favorite) => favorite.series?.name ?? null,
    }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      resolve: (favorite) => favorite.series?.volume ?? null,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      resolve: (favorite) => favorite.coverUrl ?? null,
    }),
  }),
})

export const DiscoverType = builder.objectRef<Discover>('Discover').implement({
  description:
    'The Découvrir tab: shelves of books to read next, each suggestion with its ' +
    'reason. The friends’ hearts are read live; the rest is what the weekly ' +
    'refresh found.',
  fields: (t) => ({
    preparedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description:
        'When the shelves were last prepared. Null before the first time: the app ' +
        'then offers to prepare them with `refreshDiscover`.',
      resolve: (discover) => discover.preparedAt ?? null,
    }),
    canRefresh: t.exposeBoolean('canRefresh', {
      description: 'Whether `refreshDiscover` would prepare a fresh set: once a day at most.',
    }),
    friendsFavorites: t.field({
      type: [FriendFavoriteType],
      description: 'Hearted by friends, not on the reader’s shelf; the most hearted first.',
      resolve: (discover) => discover.friendsFavorites,
    }),
    audible: t.field({
      type: [SuggestionType],
      description: 'The next recordings of the sagas the reader listens to on Audible.',
      resolve: (discover) => discover.audible,
    }),
    releases: t.field({
      type: [ReleaseType],
      description:
        'What comes out in the reader’s sagas, by their loved authors, and in ' +
        'their language for books they read in another; the soonest first.',
      resolve: (discover) => discover.releases,
    }),
    becauseYouLoved: t.field({
      type: [LovedShelfType],
      resolve: (discover) => discover.becauseYouLoved,
    }),
    awards: t.field({
      type: [SuggestionType],
      description: 'Prize winners in the reader’s leading genres.',
      resolve: (discover) => discover.awards,
    }),
    acclaimed: t.field({
      type: [SuggestionType],
      description: 'The books readers worldwide rate highest in the reader’s genres.',
      resolve: (discover) => discover.acclaimed,
    }),
    offTrail: t.field({
      type: [SuggestionType],
      description:
        'Genres the reader never tried, reached through one they love; the first ' +
        'is the hero of the week.',
      resolve: (discover) => discover.offTrail,
    }),
  }),
})
