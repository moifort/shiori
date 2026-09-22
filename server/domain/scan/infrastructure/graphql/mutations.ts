import { match, P } from 'ts-pattern'
import { imageWithinSizeLimit } from '~/domain/scan/limits'
import type { ScanOutcome } from '~/domain/scan/use-case'
import { ScanUseCase } from '~/domain/scan/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { languageFrom } from '~/domain/shared/language'
import { ScanResultType } from './types'

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
