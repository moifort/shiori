import { AudibleQuery } from '~/domain/audible/query'
import { storeUrlOf } from '~/domain/awaited-edition/business-rules'
import { AwaitedStateEnum } from '~/domain/awaited-edition/infrastructure/graphql/types'
import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import { ReleaseFormatEnum } from '~/domain/discovery/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import type {
  MonthlyDiscoveries,
  SuggestionReference,
  SuggestionView,
} from '~/domain/suggestion/types'

export const SuggestionKindEnum = builder.enumType('SuggestionKind', {
  description: 'What a suggested book is, as the model named it.',
  values: {
    NOVEL: { value: 'novel', description: 'A novel, or any prose fiction.' },
    ESSAY: { value: 'essay', description: 'Non-fiction: an essay, history, a biography.' },
    COMIC: { value: 'comic', description: 'A bande dessinée or a comic.' },
    MANGA: { value: 'manga', description: 'A manga.' },
  } as const,
})

const SuggestionReferenceType = builder
  .objectRef<SuggestionReference>('SuggestionReference')
  .implement({
    description:
      'One of the reader’s own books a suggestion was drawn from, with how it ranks for them.',
    fields: (t) => ({
      bookId: t.field({
        type: 'BookId',
        description: 'The reader’s book — a saga’s first volume when the saga was cited.',
        resolve: (reference) => reference.bookId,
      }),
      seriesId: t.field({
        type: 'SeriesId',
        nullable: true,
        resolve: (reference) => reference.seriesId ?? null,
      }),
      title: t.string({
        description: 'The saga’s name when a saga was cited, else the book’s title.',
        resolve: (reference) => reference.title,
      }),
      favorite: t.boolean({ resolve: (reference) => reference.rank.favorite }),
      rating: t.field({
        type: 'StarRating',
        nullable: true,
        resolve: (reference) => reference.rank.rating ?? null,
      }),
      viaSeries: t.boolean({
        description: 'Whether the heart or the stars are the saga’s, the book having none.',
        resolve: (reference) => reference.rank.viaSeries,
      }),
    }),
  })

export const SuggestionType = builder.objectRef<SuggestionView>('Suggestion').implement({
  description:
    'A book chosen for the reader from their library’s hearts and stars, with why, as its ' +
    'edition stands in one format and the app’s language.',
  fields: (t) => ({
    id: t.string({
      description: 'Stable for a book: what `dismissSuggestion` takes.',
      resolve: (view) => view.suggestion.key,
    }),
    format: t.field({ type: ReleaseFormatEnum, resolve: (view) => view.format }),
    title: t.field({
      type: 'BookTitle',
      description:
        'Its title in the app’s language: the edition’s once found, else the model’s, ' +
        'which may be a guess for a recent translation.',
      resolve: (view) => view.watch?.found?.title ?? view.suggestion.title,
    }),
    originalTitle: t.field({ type: 'BookTitle', resolve: (view) => view.suggestion.originalTitle }),
    originalLanguage: t.field({
      type: BookLanguageEnum,
      resolve: (view) => view.suggestion.language,
    }),
    authors: t.field({ type: ['AuthorName'], resolve: (view) => view.suggestion.authors }),
    kind: t.field({ type: SuggestionKindEnum, resolve: (view) => view.suggestion.kind }),
    reason: t.string({
      description: 'Why, in one sentence citing a book of the reader’s.',
      resolve: (view) => view.suggestion.reason,
    }),
    short: t.string({
      description: 'Two or three words: "comme Gagner la guerre".',
      resolve: (view) => view.suggestion.short,
    }),
    references: t.field({
      type: [SuggestionReferenceType],
      description: 'The reader’s books the reason draws on, in the order it cites them.',
      resolve: (view) => view.references,
    }),
    state: t.field({
      type: AwaitedStateEnum,
      description:
        'Where its edition stands: out, announced, or not found — not found also while ' +
        'nobody awaited it, which `watched` tells apart.',
      resolve: (view) => view.state,
    }),
    watched: t.boolean({ resolve: (view) => view.watch !== undefined }),
    date: t.string({
      nullable: true,
      description: 'When the edition came out or comes out, once found.',
      resolve: (view) => view.watch?.found?.date ?? null,
    }),
    coverUrl: t.string({
      nullable: true,
      description: 'The edition’s cover once found, else its page’s, else a catalogue’s.',
      resolve: (view) => view.watch?.found?.coverUrl ?? view.describedCoverUrl ?? null,
    }),
    storeUrl: t.string({
      nullable: true,
      description: 'Where to get it once its edition is found, as an award winner’s.',
      resolve: async (view, _args, { userId }) => {
        const found = view.watch?.found
        if (!found) return null
        const asin = view.format === 'audiobook' ? found.asin : undefined
        const own = asin ? await AudibleQuery.recordingUrlOf(userId, asin) : undefined
        return (
          own ?? storeUrlOf(view.format, view.language, found, view.suggestion.authors[0]) ?? null
        )
      },
    }),
    awaitableFormats: t.field({
      type: [ReleaseFormatEnum],
      description:
        'The formats its edition may be awaited in from its page, with `awaitScannedEdition`.',
      resolve: (view) => view.awaitableFormats,
    }),
    awaitedEditionId: t.field({
      type: 'AwaitedEditionId',
      nullable: true,
      resolve: (view) => view.awaitedId ?? null,
    }),
  }),
})

const DiscoveriesStatusEnum = builder.enumType('DiscoveriesStatus', {
  description: 'Where the month’s selection of discoveries stands.',
  values: {
    READY: {
      value: 'ready',
      description: 'Made for this month: its suggestions, or none once they ran out.',
    },
    SEARCHING: {
      value: 'searching',
      description: 'Being made by another request: ask again in a few seconds.',
    },
    NONE: {
      value: 'none',
      description:
        'Not made for this month: Découvrir was not opened yet, the model failed, or the ' +
        'server has no model key.',
    },
  } as const,
})

export const MonthlyDiscoveriesType = builder
  .objectRef<MonthlyDiscoveries>('MonthlyDiscoveries')
  .implement({
    description:
      'Découvrir’s discoveries of the month: books chosen for the reader by Claude from ' +
      'their hearts and stars, each with why.',
    fields: (t) => ({
      month: t.string({
        description: '`YYYY-MM`: the month the line is titled after.',
        resolve: (discoveries) => discoveries.month,
      }),
      status: t.field({
        type: DiscoveriesStatusEnum,
        resolve: (discoveries) => discoveries.status,
      }),
      suggestions: t.field({
        type: [SuggestionType],
        description:
          'Every one of the month’s selection the reader neither holds, dismissed nor awaits. Empty when none ' +
          'are left, or the server has no model key.',
        resolve: (discoveries) => discoveries.suggestions,
      }),
    }),
  })
