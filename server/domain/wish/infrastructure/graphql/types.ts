import { AwaitedEditionType } from '~/domain/awaited-edition/infrastructure/graphql/types'
import type { AwaitedEditionView } from '~/domain/awaited-edition/types'
import { BookFormatEnum, BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'
import type { Wish } from '~/domain/wish/types'

export const WishOriginEnum = builder.enumType('WishOrigin', {
  description: 'Where the reader came across a book they wish for.',
  values: {
    FRIEND: { value: 'friend', description: 'On a friend’s shelf.' },
    DISCOVERY: { value: 'discovery', description: 'Among the month’s discoveries.' },
    AWARD: { value: 'award', description: 'Among an award’s winners.' },
    AUTHOR: { value: 'author', description: 'Among the works of an author.' },
    SCAN: { value: 'scan', description: 'Scanned, and not added.' },
  } as const,
})

export const WishType = builder.objectRef<Wish>('Wish').implement({
  description:
    'A book the reader does not hold and would like to. Private to its reader, never ' +
    'counted, grouped into a saga nor shared: only the catalogue facts of the page it ' +
    'was wished from. It goes on its own once the library holds the story — scanned, ' +
    'synced, or added from anywhere.',
  fields: (t) => ({
    id: t.field({ type: 'WishId', resolve: (wish) => wish.id }),
    title: t.field({ type: 'BookTitle', resolve: (wish) => wish.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (wish) => wish.authors }),
    format: t.field({ type: BookFormatEnum, resolve: (wish) => wish.format }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      resolve: (wish) => wish.language ?? null,
    }),
    seriesName: t.field({
      type: 'SeriesName',
      nullable: true,
      resolve: (wish) => wish.series?.name ?? null,
    }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      resolve: (wish) => wish.series?.volume ?? null,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      resolve: (wish) => wish.coverUrl ?? null,
    }),
    isbn13: t.field({ type: 'Isbn13', nullable: true, resolve: (wish) => wish.isbn13 ?? null }),
    origin: t.field({ type: WishOriginEnum, resolve: (wish) => wish.origin.kind }),
    originLabel: t.string({
      nullable: true,
      description:
        'Who or what it came from, as the cover labels it: the friend’s first name, the ' +
        'award’s. Null where the origin says it all.',
      resolve: (wish) => wish.origin.label ?? null,
    }),
    friendId: t.field({
      type: 'UserId',
      nullable: true,
      description: 'The friend it was seen at, for a wish from a friend’s shelf.',
      resolve: (wish) => wish.origin.friendId ?? null,
    }),
    wishedAt: t.field({ type: 'DateTime', resolve: (wish) => wish.wishedAt }),
  }),
})

export type WishlistView = { wishes: Wish[]; awaited: AwaitedEditionView[] }

export const WishlistType = builder.objectRef<WishlistView>('Wishlist').implement({
  description:
    'Everything the reader would like and does not hold: the books they wished for, and ' +
    'the editions they await.',
  fields: (t) => ({
    wishes: t.field({
      type: [WishType],
      description: 'The books wished for, the latest first.',
      resolve: (list) => list.wishes,
    }),
    awaited: t.field({
      type: [AwaitedEditionType],
      description:
        'Every edition awaited, in both formats: the ones out first, then the ones ' +
        'announced, the soonest first, then the ones not announced.',
      resolve: (list) => list.awaited,
    }),
  }),
})
