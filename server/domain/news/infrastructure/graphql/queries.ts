import { BookFormatEnum } from '~/domain/book/infrastructure/graphql/enums'
import {
  FeedPageType,
  NarratorNewsType,
  UpcomingReleaseType,
} from '~/domain/news/infrastructure/graphql/types'
import { NewsUseCase } from '~/domain/news/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.queryFields((t) => ({
  newsFeed: t.field({
    type: FeedPageType,
    description:
      'What the reader’s friends did lately — picked a book up, finished it, loved it — ' +
      'newest first, one page at a time. A book a friend keeps to themselves is never in it.',
    args: {
      limit: t.arg.int({ defaultValue: 20, description: 'Maximum events in the page' }),
      after: t.arg.string({
        required: false,
        description: 'Cursor: `nextCursor` of the previous page',
      }),
    },
    resolve: (_root, args, context) =>
      NewsUseCase.feed(
        context.userId,
        Math.max(1, Math.min(args.limit ?? 20, 50)),
        args.after ?? undefined,
      ),
  }),

  narratorNews: t.field({
    type: [NarratorNewsType],
    description:
      'The recordings the narrators the reader follows lent their voice to in the last ' +
      'month, the newest first, the ones the reader holds left out. Read off the shared ' +
      'narrator watches a quarterly pass keeps: no web lookup.',
    resolve: (_root, _args, context) => NewsUseCase.narratorNews(context.userId),
  }),

  upcomingReleases: t.field({
    type: [UpcomingReleaseType],
    description:
      'Everything announced across the sagas the reader follows, the authors they hold and ' +
      'the editions they await, the soonest first and the undated last. Read off the ' +
      'release watches: no web lookup.',
    args: {
      format: t.arg({
        type: BookFormatEnum,
        required: false,
        description: 'Keep only this format. Omit for all of them.',
      }),
    },
    resolve: (_root, args, context) =>
      NewsUseCase.upcoming(
        context.userId,
        languageOf(context.event),
        args.format === 'ebook' ? 'book' : (args.format ?? undefined),
      ),
  }),
}))
