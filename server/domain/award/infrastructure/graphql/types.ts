import { AudibleQuery } from '~/domain/audible/query'
import { storeUrlOf } from '~/domain/awaited-edition/business-rules'
import { AwaitedStateEnum } from '~/domain/awaited-edition/infrastructure/graphql/types'
import type {
  AwardedWorkView,
  AwardList,
  AwardMention,
  AwardSection,
  AwardShelf,
} from '~/domain/award/types'
import { BookLanguageEnum, GenreEnum } from '~/domain/book/infrastructure/graphql/enums'
import { ReleaseFormatEnum } from '~/domain/discovery/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'

export const AwardEnum = builder.enumType('Award', {
  description: 'A literary award whose novel winners Découvrir lists.',
  values: {
    HUGO: { value: 'hugo', description: 'The Hugo Award for Best Novel.' },
    NEBULA: { value: 'nebula', description: 'The Nebula Award for Best Novel.' },
    LOCUS_SF: { value: 'locus-sf', description: 'The Locus Award for Best Science Fiction Novel.' },
    LOCUS_FANTASY: {
      value: 'locus-fantasy',
      description: 'The Locus Award for Best Fantasy Novel.',
    },
    CLARKE: { value: 'clarke', description: 'The Arthur C. Clarke Award.' },
    WORLD_FANTASY: {
      value: 'world-fantasy',
      description: 'The World Fantasy Award for Best Novel.',
    },
  } as const,
})

const AwardMentionType = builder.objectRef<AwardMention>('AwardMention').implement({
  description: 'One prize a novel won.',
  fields: (t) => ({
    award: t.field({ type: AwardEnum, resolve: (mention) => mention.award }),
    year: t.int({
      description: 'The year it was presented, not the year the novel came out.',
      resolve: (mention) => mention.year,
    }),
  }),
})

export const AwardWinnerType = builder.objectRef<AwardedWorkView>('AwardWinner').implement({
  description:
    'A novel crowned at the latest ceremony of one of the awards, as its edition stands ' +
    'in one format and the app’s language. Looked up on the web only once a reader ' +
    'awaits it, shared by every reader.',
  fields: (t) => ({
    id: t.string({
      description: 'The edition’s shared watch: stable for a novel, format and language.',
      resolve: (view) => view.watchKey,
    }),
    format: t.field({ type: ReleaseFormatEnum, resolve: (view) => view.format }),
    title: t.field({
      type: 'BookTitle',
      description: 'Its title in the app’s language once found, else the one it won under.',
      resolve: (view) => view.watch?.found?.title ?? view.work.title,
    }),
    originalTitle: t.field({
      type: 'BookTitle',
      description: 'The title it won under, in English.',
      resolve: (view) => view.work.title,
    }),
    originalLanguage: t.field({
      type: BookLanguageEnum,
      resolve: (view) => view.work.language,
    }),
    authors: t.field({ type: ['AuthorName'], resolve: (view) => view.work.authors }),
    awards: t.field({
      type: [AwardMentionType],
      description: 'Every prize it won among the genre’s awards, the newest first.',
      resolve: (view) => view.work.mentions,
    }),
    state: t.field({
      type: AwaitedStateEnum,
      description:
        'Where its edition stands: out, announced, or not found. Not found also for a ' +
        'novel nobody awaited, never looked up: `watched` tells them apart.',
      resolve: (view) => view.state,
    }),
    watched: t.boolean({
      description: 'Whether the web was ever searched for its edition.',
      resolve: (view) => view.watch !== undefined,
    }),
    date: t.string({
      nullable: true,
      description:
        'When the edition came out or comes out: `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Null ' +
        'until found, and for an edition found with no date.',
      resolve: (view) => view.watch?.found?.date ?? null,
    }),
    coverUrl: t.string({
      nullable: true,
      description:
        'The edition’s cover once found, else the one its page found when it was described.',
      resolve: (view) => view.watch?.found?.coverUrl ?? view.describedCoverUrl ?? null,
    }),
    storeUrl: t.string({
      nullable: true,
      description:
        'Where to get it: the recording’s page on the reader’s Audible store, or a ' +
        'search for it there while Audible has not confirmed it; the printed edition’s ' +
        'page on Amazon once its ISBN is known. Null until the edition is found.',
      resolve: async (view, _args, { userId }) => {
        const found = view.watch?.found
        if (!found) return null
        const asin = view.format === 'audiobook' ? found.asin : undefined
        const own = asin ? await AudibleQuery.recordingUrlOf(userId, asin) : undefined
        return own ?? storeUrlOf(view.format, view.language, found, view.work.authors[0]) ?? null
      },
    }),
    awaitable: t.boolean({
      description:
        'Whether it may be awaited from its row, with `awaitScannedEdition`: not out, not ' +
        'awaited already, and in a format its edition can be awaited in.',
      resolve: (view) => view.awaitable,
    }),
    awaitedEditionId: t.field({
      type: 'AwaitedEditionId',
      nullable: true,
      description: 'The edition the reader awaits already, when they do.',
      resolve: (view) => view.awaitedId ?? null,
    }),
  }),
})

const AwardListType = builder.objectRef<AwardList>('AwardList').implement({
  description: 'One award’s winners, for the full list.',
  fields: (t) => ({
    award: t.field({ type: AwardEnum, resolve: (list) => list.award }),
    winners: t.field({
      type: [AwardWinnerType],
      description: 'Its winners the reader does not hold in that format, the newest first.',
      resolve: (list) => list.winners,
    }),
    readCount: t.int({
      description: 'How many of all its winners the reader has read, in any format.',
      resolve: (list) => list.readCount,
    }),
    total: t.int({ description: 'How many novels it crowned.', resolve: (list) => list.total }),
  }),
})

export const AwardShelfType = builder.objectRef<AwardShelf>('AwardShelf').implement({
  description:
    'Découvrir’s award winners: the novels the awards of the reader’s genre crowned, ' +
    'with where their edition stands in the app’s language.',
  fields: (t) => ({
    genre: t.field({
      type: GenreEnum,
      description: 'The genre shown: the one asked for, else the one the reader reads most.',
      resolve: (shelf) => shelf.genre,
    }),
    genres: t.field({
      type: [GenreEnum],
      description: 'Every genre with awards the reader reads enough, the most read first.',
      resolve: (shelf) => shelf.genres,
    }),
    recent: t.field({
      type: [AwardWinnerType],
      description:
        'The latest winners across the genre’s awards the reader does not hold in that ' +
        'format, twelve at most, the newest first.',
      resolve: (shelf) => shelf.recent,
    }),
    awards: t.field({
      type: [AwardListType],
      description: 'Each of the genre’s awards in full, its own first.',
      resolve: (shelf) => shelf.awards,
    }),
  }),
})

export const AwardSectionType = builder.objectRef<AwardSection>('AwardSection').implement({
  description:
    'One genre’s section of Découvrir’s award winners: the latest novels its awards ' +
    'crowned that the reader does not hold, none of them drawn in another section.',
  fields: (t) => ({
    genre: t.field({ type: GenreEnum, resolve: (section) => section.genre }),
    winners: t.field({
      type: [AwardWinnerType],
      description:
        'Its latest winners the reader does not hold in that format, twelve at most, the ' +
        'newest first.',
      resolve: (section) => section.winners,
    }),
  }),
})
