import { BookFormatEnum } from '~/domain/book/infrastructure/graphql/enums'
import { FeedEventKindEnum, ReleaseSourceEnum } from '~/domain/news/infrastructure/graphql/enums'
import type { FeedEvent, FeedPage, NarratorNews, UpcomingRelease } from '~/domain/news/types'
import { builder } from '~/domain/shared/graphql/builder'
import { objectStore } from '~/system/object-store'

export const FeedEventType = builder.objectRef<FeedEvent>('FeedEvent').implement({
  description: 'One thing a friend did to a book, for the Actualités feed.',
  fields: (t) => ({
    id: t.string({ resolve: (event) => event.id }),
    kind: t.field({ type: FeedEventKindEnum, resolve: (event) => event.kind }),
    at: t.field({ type: 'DateTime', resolve: (event) => event.at }),
    friendId: t.field({ type: 'UserId', resolve: (event) => event.friend.userId }),
    friendFirstName: t.string({
      nullable: true,
      description: 'Null for an account that never finished its onboarding.',
      resolve: (event) => event.friend.firstName ?? null,
    }),
    bookId: t.field({
      type: 'BookId',
      description: 'The friend’s record: open it with `friendBook`.',
      resolve: (event) => event.book.id,
    }),
    title: t.field({ type: 'BookTitle', resolve: (event) => event.book.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (event) => event.book.authors }),
    format: t.field({ type: BookFormatEnum, resolve: (event) => event.book.format }),
    coverUrl: t.string({
      nullable: true,
      description: 'Their photo of the cover, else the publisher’s.',
      resolve: async ({ book }) =>
        book.coverPath
          ? await objectStore().downloadUrl(book.coverPath)
          : (book.publishedCoverUrl ?? null),
    }),
    rating: t.field({
      type: 'StarRating',
      nullable: true,
      description: 'Their stars, when they gave any.',
      resolve: (event) => event.rating ?? null,
    }),
    alsoStartedBy: t.int({
      description: 'How many of the reader’s other friends picked up the same story lately.',
      resolve: (event) => event.alsoStartedBy,
    }),
    inLibrary: t.boolean({
      description: 'Whether the reader already holds the story, on any shelf.',
      resolve: (event) => event.inLibrary,
    }),
  }),
})

export const FeedPageType = builder.objectRef<FeedPage>('FeedPage').implement({
  description: 'One page of the news feed, newest first.',
  fields: (t) => ({
    events: t.field({ type: [FeedEventType], resolve: (page) => page.events }),
    nextCursor: t.string({
      nullable: true,
      description: 'Pass it as `after` for the next page. Null on the last one.',
      resolve: (page) => page.nextCursor ?? null,
    }),
  }),
})

const UpcomingAuthorType = builder
  .objectRef<NonNullable<UpcomingRelease['author']>>('UpcomingReleaseAuthor')
  .implement({
    description: 'The author of an upcoming release the reader holds.',
    fields: (t) => ({
      key: t.field({ type: 'AuthorKey', resolve: (author) => author.key }),
      name: t.field({ type: 'AuthorName', resolve: (author) => author.name }),
      favorite: t.boolean({
        description: 'Whether the reader hearted the author.',
        resolve: (author) => author.favorite,
      }),
      portraitUrl: t.field({
        type: 'PortraitUrl',
        nullable: true,
        resolve: (author) => author.portraitUrl ?? null,
      }),
    }),
  })

const UpcomingSeriesType = builder
  .objectRef<NonNullable<UpcomingRelease['series']>>('UpcomingReleaseSeries')
  .implement({
    description: 'The saga an upcoming release belongs to.',
    fields: (t) => ({
      name: t.field({ type: 'SeriesName', resolve: (series) => series.name }),
      volume: t.field({
        type: 'VolumeNumber',
        nullable: true,
        resolve: (series) => series.volume ?? null,
      }),
    }),
  })

export const UpcomingReleaseType = builder.objectRef<UpcomingRelease>('UpcomingRelease').implement({
  description: 'One book announced, merged from the reader’s follows.',
  fields: (t) => ({
    id: t.string({ resolve: (release) => release.id }),
    source: t.field({ type: ReleaseSourceEnum, resolve: (release) => release.source }),
    format: t.field({ type: BookFormatEnum, resolve: (release) => release.format }),
    title: t.field({
      type: 'BookTitle',
      nullable: true,
      description: 'Null on an announcement that names no title yet.',
      resolve: (release) => release.title ?? null,
    }),
    authors: t.field({ type: ['AuthorName'], resolve: (release) => release.authors }),
    date: t.string({
      nullable: true,
      description:
        'As precisely as announced: `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Null when announced ' +
        'for a date nobody found.',
      resolve: (release) => release.date ?? null,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      resolve: (release) => release.coverUrl ?? null,
    }),
    series: t.field({
      type: UpcomingSeriesType,
      nullable: true,
      resolve: (release) => release.series ?? null,
    }),
    author: t.field({
      type: UpcomingAuthorType,
      nullable: true,
      description: 'Set on a work of an author the reader holds.',
      resolve: (release) => release.author ?? null,
    }),
    sagaRating: t.field({
      type: 'StarRating',
      nullable: true,
      description: 'The reader’s stars for the saga, when it is a saga’s volume.',
      resolve: (release) => release.sagaRating ?? null,
    }),
    sagaFavorite: t.boolean({
      description: 'Whether the reader hearted the saga.',
      resolve: (release) => release.sagaFavorite,
    }),
    narrator: t.string({
      nullable: true,
      description: 'The narrator who lends their voice, on a recording found for one.',
      resolve: (release) => release.narrator ?? null,
    }),
  }),
})

export const NarratorNewsType = builder.objectRef<NarratorNews>('NarratorNews').implement({
  description:
    'A narrator the reader follows lending their voice to a recording out in the last month, ' +
    'for the news feed.',
  fields: (t) => ({
    id: t.string({ resolve: (news) => news.id }),
    narratorKey: t.field({ type: 'NarratorKey', resolve: (news) => news.narratorKey }),
    narrator: t.string({ resolve: (news) => news.narrator }),
    title: t.field({ type: 'BookTitle', resolve: (news) => news.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (news) => news.authors }),
    date: t.string({
      description: 'When it came out: `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.',
      resolve: (news) => news.date,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      resolve: (news) => news.coverUrl ?? null,
    }),
  }),
})
