import { match, P } from 'ts-pattern'
import {
  BookFormatEnum,
  BookLanguageEnum,
  heldAs,
} from '~/domain/book/infrastructure/graphql/enums'
import {
  AnnouncedVolumePreviewType,
  DiscoveryType,
  ReleaseDescriptionType,
  ReleaseFormatEnum,
  SagaReleasesType,
} from '~/domain/discovery/infrastructure/graphql/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { ReleaseDate } from '~/domain/series/primitives'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError, notFound } from '~/domain/shared/graphql/errors'
import { languageOf } from '~/domain/shared/language'

/** A book Découvrir shows, as the app names it. */
const ReleaseInput = builder.inputType('ReleaseInput', {
  description:
    'A book Découvrir shows — a saga’s volume, an edition awaited, an award winner — named ' +
    'by what the app already knows of it.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', required: true }),
    authors: t.field({ type: ['AuthorName'], required: true }),
    format: t.field({ type: BookFormatEnum, required: true }),
    language: t.field({
      type: BookLanguageEnum,
      required: false,
      description: 'The edition’s language. Absent, the book is described in the app’s.',
    }),
    seriesId: t.field({
      type: 'SeriesId',
      required: false,
      description: 'The saga it is a volume of, with `seriesName` and `volume`.',
    }),
    seriesName: t.field({ type: 'SeriesName', required: false }),
    volume: t.field({ type: 'VolumeNumber', required: false }),
    isbn13: t.field({
      type: 'Isbn13',
      required: false,
      description: 'The ISBN the web search found, for the model to check.',
    }),
    releasedOn: t.string({
      required: false,
      description:
        'When it comes or came out, as found: `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Ignored ' +
        'when it is none of them.',
    }),
    coverUrl: t.field({ type: 'CoverUrl', required: false }),
  }),
})

/** A hint the model is told, dropped when it is not a date. */
const releasedOnOf = (value: string | null | undefined) => {
  if (!value) return undefined
  try {
    return ReleaseDate(value)
  } catch {
    return undefined
  }
}

builder.mutationFields((t) => ({
  describeRelease: t.field({
    type: ReleaseDescriptionType,
    description:
      'Describe a book Découvrir shows, for its page, as a scan describes one: the ' +
      'web-grounded model fills in its summary, genre, pages and publisher, and Audible the ' +
      'narrators and running time of a recording. About ten seconds the first time.\n\n' +
      'Kept for every reader who opens the same book in the same language, for sixty ' +
      'days: the call is paid once and spends nobody’s scan. Refused with ' +
      '`QUOTA_EXHAUSTED` when the reader’s allowance is used up and nobody described it ' +
      'yet, `SCAN_FAILED` when the model call errors.',
    args: { book: t.arg({ type: ReleaseInput, required: true }) },
    resolve: async (_root, { book }, context) =>
      match(
        await DiscoveryUseCase.describeRelease(
          context.userId,
          {
            title: book.title,
            authors: book.authors,
            format: heldAs(book.format).format ?? 'book',
            ...(book.language ? { language: book.language } : {}),
            ...(book.seriesId && book.seriesName
              ? {
                  series: {
                    id: book.seriesId,
                    name: book.seriesName,
                    kind: 'main' as const,
                    ...(book.volume != null ? { volume: book.volume } : {}),
                  },
                }
              : {}),
            ...(book.isbn13 ? { isbn13: book.isbn13 } : {}),
            ...(releasedOnOf(book.releasedOn) ? { releasedOn: releasedOnOf(book.releasedOn) } : {}),
            ...(book.coverUrl ? { coverUrl: book.coverUrl } : {}),
          },
          languageOf(context.event),
        ),
      )
        .with('quota-exhausted', () => domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up'))
        .with({ failed: P.string }, ({ failed }) => domainError('SCAN_FAILED', failed))
        .with({ book: P.any }, (description) => description)
        .exhaustive(),
  }),
  lookUpDiscovery: t.field({
    type: DiscoveryType,
    description:
      'Look up now, on the web, every saga, then every author, the reader follows in that ' +
      'format that was never looked up, rather than wait for the hourly pass — for the first look at the ' +
      'tab, and a saga followed since. Slow: grounded model calls, a few side by side, up ' +
      'to about ninety seconds; whatever is left goes to the hourly pass. Answers the tab.',
    args: { format: t.arg({ type: ReleaseFormatEnum, required: true }) },
    resolve: (_root, { format }, context) =>
      DiscoveryUseCase.lookUpUnwatched(context.userId, languageOf(context.event), format),
  }),
  lookUpSagaReleases: t.field({
    type: SagaReleasesType,
    description:
      'Look a saga up on the web now in the edition opened, when nobody ever did — one ' +
      'grounded call, about ten seconds — and answer what it has for the reader. An ' +
      'edition already looked up is answered as it stands.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({ type: BookLanguageEnum, required: true }),
    },
    resolve: (_root, { seriesId, language }, context) =>
      DiscoveryUseCase.lookUpSaga(context.userId, seriesId, language),
  }),
  previewAnnouncedVolume: t.field({
    type: AnnouncedVolumePreviewType,
    description:
      'Describe a volume the release watch announced, for its page before the reader adds ' +
      'it. A printed volume is described by the web-grounded model; a recording Audible ' +
      'confirmed is read off Audible’s catalogue first, and the model adds its summary, ' +
      'genre and first publication. A few seconds. Nothing is saved.\n\n' +
      'Spends one scan of the allowance, as a typed title does. Fails with `NOT_FOUND` for ' +
      'a volume no watch announced in that edition, `QUOTA_EXHAUSTED` once nothing is left, ' +
      'or `SCAN_FAILED` when the model call errors.',
    deprecationReason:
      'The volume page draws what `discovery` already carries, with no model call.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({ type: BookLanguageEnum, required: true }),
      number: t.arg({ type: 'VolumeNumber', required: true }),
    },
    resolve: async (_root, { seriesId, language, number }, context) =>
      match(
        await DiscoveryUseCase.previewAnnouncedVolume(
          context.userId,
          { seriesId, language, number },
          languageOf(context.event),
        ),
      )
        .with('not-found', () => notFound('No such volume announced'))
        .with('quota-exhausted', () => domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up'))
        .with({ failed: P.string }, ({ failed }) => domainError('SCAN_FAILED', failed))
        .with({ book: P.any }, (preview) => preview)
        .exhaustive(),
  }),
}))
