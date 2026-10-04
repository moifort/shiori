import { match, P } from 'ts-pattern'
import {
  BookFormatEnum,
  BookLanguageEnum,
  BookMediumEnum,
  heldAs,
} from '~/domain/book/infrastructure/graphql/enums'
import { imageWithinSizeLimit } from '~/domain/scan/limits'
import type { ScanOutcome, ShelfOutcome } from '~/domain/scan/use-case'
import { ScanUseCase } from '~/domain/scan/use-case'
import { VolumeKindEnum } from '~/domain/series/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { languageFrom } from '~/domain/shared/language'
import { DetectedBookType, ScanResultType, TitleCandidateType } from './types'

const answered = (outcome: ScanOutcome) =>
  match(outcome)
    .with('quota-exhausted', () => domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up'))
    .with({ failed: P.string }, ({ failed }) => domainError('SCAN_FAILED', failed))
    .with({ recognized: P.boolean }, (result) => result)
    .exhaustive()

builder.mutationField('scanLink', (t) =>
  t.field({
    type: ScanResultType,
    description:
      'Look a book up from a page the reader shared — a bookshop, a review, a ' +
      'library catalogue — and return a record to review.\n\n' +
      "The page is fetched for its title, the shop's own name and the format " +
      'stripped off it, and the rest goes through the same lookup a typed title ' +
      'does. A page that does not answer, is not a page, or has no title falls ' +
      'back to `recognized: false` rather than failing: a shared link is a ' +
      'convenience, not a contract.\n\n' +
      'Spends one scan of the allowance, and only when the title was found — a ' +
      'link that led nowhere costs the reader nothing.',
    args: {
      url: t.arg.string({ required: true, description: 'The page that was shared' }),
    },
    resolve: async (_root, { url }, { userId, event }) =>
      answered(
        await ScanUseCase.lookUpLink(
          userId,
          url,
          languageFrom(event && getHeader(event, 'accept-language')),
        ),
      ),
  }),
)

builder.mutationField('scanTitle', (t) =>
  t.field({
    type: ScanResultType,
    description:
      'Look a book up from a title the reader typed and return a record to review, ' +
      'as `scanBook` does from a cover.\n\n' +
      'The title can be approximate: the model looks for the most likely book and ' +
      'answers with its exact title. Nothing is saved; the reader corrects the ' +
      'proposal and `addBook` persists it.\n\n' +
      'Two model calls at most — the web-grounded enrichment, and a series ' +
      'catalogue only when the saga is not already known. Never cached, and always ' +
      'spends one scan of the allowance. Fails with `QUOTA_EXHAUSTED` once nothing ' +
      'is left, or `SCAN_FAILED` when the model call errors.',
    args: {
      title: t.arg({ type: 'BookTitle', required: true, description: 'The title as remembered' }),
    },
    resolve: async (_root, { title }, { userId, event }) =>
      answered(
        await ScanUseCase.lookUpTitle(
          userId,
          title,
          languageFrom(event && getHeader(event, 'accept-language')),
        ),
      ),
  }),
)

builder.mutationField('searchTitle', (t) =>
  t.field({
    type: [TitleCandidateType],
    description:
      'List the books a typed title may mean, most likely first and five at most, ' +
      'so the reader picks one before `scanTitle` builds its record.\n\n' +
      'One model call without web search, so it answers in seconds. An empty list ' +
      'means nothing matched; a single entry means the title was unambiguous.\n\n' +
      'Spends nothing — the scan is the `scanTitle` that follows — but is refused ' +
      'with `QUOTA_EXHAUSTED` once the allowance is used up, since that lookup ' +
      'would be. Fails with `SCAN_FAILED` when the model call errors.',
    args: {
      title: t.arg({ type: 'BookTitle', required: true, description: 'The title as remembered' }),
    },
    resolve: async (_root, { title }, { userId, event }) =>
      match(
        await ScanUseCase.searchTitle(
          userId,
          title,
          languageFrom(event && getHeader(event, 'accept-language')),
        ),
      )
        .with('quota-exhausted', () => domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up'))
        .with({ failed: P.string }, ({ failed }) => domainError('SCAN_FAILED', failed))
        .with(P.array(), (candidates) => candidates)
        .exhaustive(),
  }),
)

builder.mutationField('scanBook', (t) =>
  t.field({
    type: ScanResultType,
    description:
      'Read a book cover with AI and return a record for the reader to review.\n\n' +
      'Nothing is saved: the answer is a proposal. The app shows it, the reader ' +
      'corrects what the model got wrong, and `addBook` persists the result. That ' +
      'review step is the safety net against a misread cover.\n\n' +
      'Three model calls at most — the cover, a web-grounded enrichment, and a ' +
      'series catalogue only when the saga is not already known. Results are ' +
      'cached by SHA-256 and language, so scanning the same cover twice calls ' +
      'nothing.\n\n' +
      'Spends one scan of the allowance (see the `quota` query): the month first, ' +
      'then the scans granted at onboarding. Only a real model call is charged — ' +
      'a cached cover is free, and so is a failure. Fails with `QUOTA_EXHAUSTED` ' +
      'once nothing is left, `IMAGE_TOO_LARGE` above the 10 MB limit, or ' +
      '`SCAN_FAILED` when the model call errors.',
    args: {
      imageBase64: t.arg.string({
        required: true,
        description: 'Cover photo as a base64-encoded JPEG (no data URL prefix), up to 10 MB',
      }),
    },
    resolve: async (_root, { imageBase64 }, { userId, event }) => {
      if (!imageWithinSizeLimit(imageBase64.length))
        return domainError('IMAGE_TOO_LARGE', 'Image exceeds the 10 MB size limit')
      // The model writes its free text in the caller's language, and the header
      // also partitions the cache so two languages never cross-contaminate.
      return answered(
        await ScanUseCase.scanCover(
          userId,
          Buffer.from(imageBase64, 'base64'),
          languageFrom(event && getHeader(event, 'accept-language')),
        ),
      )
    },
  }),
)

const DetectedBookInput = builder.inputType('DetectedBookInput', {
  description:
    'A book ticked on the shelf checklist, as the reader left it: what `detectBooks` ' +
    'read, with any title or author they corrected.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', required: true }),
    authors: t.field({ type: ['AuthorName'], required: true }),
    publisher: t.field({ type: 'Publisher' }),
    language: t.field({ type: BookLanguageEnum }),
    format: t.field({ type: BookFormatEnum }),
    media: t.field({ type: [BookMediumEnum] }),
  }),
})

const shelfAnswered = (outcome: ShelfOutcome) =>
  match(outcome)
    .with('premium-required', () =>
      domainError('PREMIUM_REQUIRED', 'Importing a shelf is a Premium feature'),
    )
    .with('quota-exhausted', () => domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up'))
    .with({ failed: P.string }, ({ failed }) => domainError('SCAN_FAILED', failed))
    .with(P.array(), (books) => books)
    .exhaustive()

builder.mutationField('detectBooks', (t) =>
  t.field({
    type: [DetectedBookType],
    description:
      'Find every book in one photo — spines on a shelf, or covers laid out flat — ' +
      'and where each sits, for the reader to tick the ones to add.\n\n' +
      'One model call without web search: only what is printed is read, and a spine ' +
      'that cannot be read comes back with no title rather than a guess. At most 30 ' +
      'books, left to right and top to bottom. Books the reader already owns are ' +
      'flagged `owned`.\n\n' +
      'Premium only: fails with `PREMIUM_REQUIRED` for a free account. Spends nothing ' +
      '— each book kept costs its own `describeDetectedBook` — but fails with ' +
      '`QUOTA_EXHAUSTED` once the allowance is used up, `IMAGE_TOO_LARGE` above the ' +
      '10 MB limit, or `SCAN_FAILED` when the model call errors.',
    args: {
      imageBase64: t.arg.string({
        required: true,
        description: 'The photo as a base64-encoded JPEG (no data URL prefix), up to 10 MB',
      }),
    },
    resolve: async (_root, { imageBase64 }, { userId, event }) => {
      if (!imageWithinSizeLimit(imageBase64.length))
        return domainError('IMAGE_TOO_LARGE', 'Image exceeds the 10 MB size limit')
      return shelfAnswered(
        await ScanUseCase.detectBooks(
          userId,
          Buffer.from(imageBase64, 'base64'),
          languageFrom(event && getHeader(event, 'accept-language')),
        ),
      )
    },
  }),
)

builder.mutationField('describeDetectedBook', (t) =>
  t.field({
    type: ScanResultType,
    description:
      'Build the record of a book ticked on the shelf checklist, as `scanBook` does ' +
      'once a cover is read: web-grounded enrichment, published cover, and the saga ' +
      'and author catalogues when nobody built them yet. Nothing is saved; `addBook` ' +
      'persists it.\n\n' +
      'Never cached, and spends one scan of the allowance once the model answered. ' +
      'Fails with `QUOTA_EXHAUSTED` once nothing is left, or `SCAN_FAILED` when the ' +
      'model call errors.',
    args: { book: t.arg({ type: DetectedBookInput, required: true }) },
    resolve: async (_root, { book }, { userId, event }) =>
      answered(
        await ScanUseCase.describeDetected(
          userId,
          {
            recognized: true,
            title: book.title,
            authors: book.authors,
            publisher: book.publisher ?? undefined,
            language: book.language ?? undefined,
            ...heldAs(book.format, book.media),
            subgenres: [],
          },
          languageFrom(event && getHeader(event, 'accept-language')),
        ),
      ),
  }),
)

const SeriesVolumeInput = builder.inputType('SeriesVolumeInput', {
  description:
    'A volume of a saga the reader is adding from its page: the catalogue already ' +
    'names its saga, its place and its edition.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', required: true }),
    authors: t.field({ type: ['AuthorName'], required: true }),
    seriesId: t.field({ type: 'SeriesId', required: true }),
    seriesName: t.field({ type: 'SeriesName', required: true }),
    volume: t.field({ type: 'VolumeNumber', description: 'Null for an unnumbered work' }),
    kind: t.field({ type: VolumeKindEnum, required: true }),
    language: t.field({ type: BookLanguageEnum }),
    format: t.field({ type: BookFormatEnum }),
    media: t.field({ type: [BookMediumEnum] }),
  }),
})

builder.mutationField('scanSeriesVolume', (t) =>
  t.field({
    type: ScanResultType,
    description:
      'Build the record of a volume the reader adds from its saga page, as ' +
      '`scanTitle` does from a typed title, but told which saga, which volume and ' +
      'which format it is: the volumes of a comic are often all titled after the ' +
      'saga, and the title alone found volume 1 for every one of them, with its ' +
      'ISBN and its cover. The answer stays filed at the volume asked for. Nothing ' +
      'is saved; `addBook` persists it.\n\n' +
      'One web-grounded model call, never cached, spending one scan of the ' +
      'allowance once the model answered. Fails with `QUOTA_EXHAUSTED` once nothing ' +
      'is left, or `SCAN_FAILED` when the model call errors.',
    args: { volume: t.arg({ type: SeriesVolumeInput, required: true }) },
    resolve: async (_root, { volume }, { userId, event }) => {
      const series = {
        id: volume.seriesId,
        name: volume.seriesName,
        volume: volume.volume ?? undefined,
        kind: volume.kind,
      }
      const outcome = await ScanUseCase.lookUpVolume(
        userId,
        {
          recognized: true,
          title: volume.title,
          authors: volume.authors,
          language: volume.language ?? undefined,
          ...heldAs(volume.format, volume.media),
          series,
          subgenres: [],
        },
        languageFrom(event && getHeader(event, 'accept-language')),
      )
      return answered(
        typeof outcome === 'object' && 'recognized' in outcome ? { ...outcome, series } : outcome,
      )
    },
  }),
)
