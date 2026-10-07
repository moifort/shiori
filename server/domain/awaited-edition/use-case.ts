import { AdminCommand } from '~/domain/admin/command'
import {
  alertIsDue,
  alertOf,
  awaitableFormatsOf,
  awaitedIdOf,
  dueWatchesOf,
  editionWatchKeyOf,
  inShelfOrder,
  isHeld,
  MAX_AWAITED,
  viewOf,
} from '~/domain/awaited-edition/business-rules'
import { AwaitedEditionCommand } from '~/domain/awaited-edition/command'
import { editionFrom } from '~/domain/awaited-edition/parsing'
import { editionPrompt } from '~/domain/awaited-edition/prompts'
import { AwaitedEditionQuery } from '~/domain/awaited-edition/query'
import { EDITION_SCHEMA, type EditionOutput } from '~/domain/awaited-edition/schemas'
import type {
  AwaitedEdition,
  AwaitedEditionId,
  AwaitedEditionView,
  AwaitedSource,
  EditionOffer,
  EditionWatch,
  ScannedBook,
} from '~/domain/awaited-edition/types'
import { coverSourcesOf } from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import type { BookId, BookView } from '~/domain/book/types'
import { todayOf } from '~/domain/discovery/business-rules'
import type { ReleaseFormat } from '~/domain/discovery/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { NotificationUseCase } from '~/domain/notification/use-case'
import { generate } from '~/domain/scan/gemini'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('awaited-edition')

/** How many grounded calls run side by side, as the release watches run theirs. */
const CALLS_AT_ONCE = 5

/** What the hourly pass may spend on the awaited editions before the sagas
 *  have their turn: the two share one function run. */
const SCHEDULED_BUDGET_MS = 40_000

export type AwaitOutcome = AwaitedEditionView | 'not-found' | 'not-awaitable' | 'too-many'

export namespace AwaitedEditionUseCase {
  /** What the page of one of the reader's own books offers. Null for a book
   *  that is not theirs. */
  export const offerForBook = async (
    userId: UserId,
    bookId: BookId,
    appLanguage: Language,
    now = new Date(),
  ): Promise<EditionOffer | null> => {
    const book = await BookQuery.byId(userId, bookId)
    return book ? offerFor(userId, book, book.userId, appLanguage, now) : null
  }

  /** The formats a book not added yet — the one a scan proposes — may be
   *  awaited in once added: what its page will offer, so the review can offer
   *  it before the book is saved. */
  export const formatsForDraft = (
    draft: Pick<BookView, 'language' | 'format'>,
    appLanguage: Language,
  ): ReleaseFormat[] => awaitableFormatsOf(draft, appLanguage)

  /** What a book's page offers: the formats its edition in the app's language
   *  may be awaited in, and the ones the reader awaits already. */
  export const offerFor = async (
    userId: UserId,
    book: BookView,
    ownerId: UserId,
    appLanguage: Language,
    now = new Date(),
  ): Promise<EditionOffer> => {
    const awaited = await awaitedOf(userId, now)
    // One awaited from the book's scan, before it was added, is this book's
    // too: it carries no record, so it is known by the edition it watches.
    const source = sourceOf(book, ownerId, userId, appLanguage)
    const unshelved = new Set(
      (['book', 'audiobook'] as const).map((format) =>
        editionWatchKeyOf(source, format, appLanguage),
      ),
    )
    return {
      formats: awaitableFormatsOf(book, appLanguage),
      awaited: awaited.filter((view) =>
        view.source.bookId
          ? view.source.bookId === book.id && view.source.ownerId === ownerId
          : unshelved.has(view.watchKey),
      ),
    }
  }

  /** Await one of the reader's own books in the app's language. */
  export const awaitOwnBook = async (
    userId: UserId,
    bookId: BookId,
    format: ReleaseFormat,
    appLanguage: Language,
    now = new Date(),
  ): Promise<AwaitOutcome> => {
    const book = await BookQuery.byId(userId, bookId)
    if (!book) return 'not-found'
    return awaitBook(userId, book, book.userId, format, appLanguage, now)
  }

  /** Await a book's edition in the app's language, in one format, and look it
   *  up on the web at once when nobody did — one grounded call — so its page
   *  says straight away whether it is announced or already out. Awaiting it
   *  twice answers the first. An edition already out when it is awaited is
   *  never pushed: the reader sees it there and then. */
  export const awaitBook = async (
    userId: UserId,
    book: BookView,
    ownerId: UserId,
    format: ReleaseFormat,
    appLanguage: Language,
    now = new Date(),
  ): Promise<AwaitOutcome> => {
    if (!awaitableFormatsOf(book, appLanguage).includes(format)) return 'not-awaitable'
    return awaitSource(
      userId,
      sourceOf(book, ownerId, userId, appLanguage),
      format,
      appLanguage,
      now,
    )
  }

  /** Await a book a scan proposed, from its review, without adding it to the
   *  library: the reader saw it in a shop and wants to know when it comes out
   *  in their language. Answered as an edition awaited from a shelf is. */
  export const awaitScannedBook = async (
    userId: UserId,
    scanned: ScannedBook,
    format: ReleaseFormat,
    appLanguage: Language,
    now = new Date(),
  ): Promise<AwaitOutcome> => {
    if (!awaitableFormatsOf(scanned, appLanguage).includes(format)) return 'not-awaitable'
    const source: AwaitedSource = {
      ownerId: userId,
      title: scanned.title,
      authors: scanned.authors,
      language: scanned.language ?? appLanguage,
      ...(scanned.series ? { series: scanned.series } : {}),
      ...(scanned.coverUrl ? { coverUrl: scanned.coverUrl } : {}),
    }
    return awaitSource(userId, source, format, appLanguage, now)
  }

  const awaitSource = async (
    userId: UserId,
    source: AwaitedSource,
    format: ReleaseFormat,
    appLanguage: Language,
    now: Date,
  ): Promise<AwaitOutcome> => {
    const watchKey = editionWatchKeyOf(source, format, appLanguage)
    const id = awaitedIdOf(userId, watchKey)
    const already = await AwaitedEditionQuery.byUser(userId)
    const today = todayOf(now)
    const watches = await AwaitedEditionQuery.watches([watchKey])
    const known = already.find((awaited) => awaited.id === id)
    if (known) return viewOf(known, watches.get(watchKey), today)
    if (already.length >= MAX_AWAITED) return 'too-many'
    const awaited = await AwaitedEditionCommand.save({
      id,
      userId,
      format,
      language: appLanguage,
      source,
      watchKey,
      awaitedAt: now,
    })
    let watch = watches.get(watchKey)
    if (!watch)
      try {
        watch = await lookUp(seedOf(awaited), undefined, now)
      } catch (error) {
        logger.warn('edition lookup failed', { error, watchKey })
      }
    const view = viewOf(awaited, watch, today)
    if (view.state !== 'available') return view
    return { ...view, ...(await AwaitedEditionCommand.markNotified(awaited, now)) }
  }

  /** Stop awaiting an edition. False when the reader awaits nothing by that id. */
  export const stopAwaiting = async (userId: UserId, id: AwaitedEditionId): Promise<boolean> => {
    const awaited = await AwaitedEditionQuery.byUser(userId)
    if (!awaited.some((edition) => edition.id === id)) return false
    await AwaitedEditionCommand.remove(userId, [id])
    return true
  }

  /** The editions the reader awaits in one format, in the shelf's order. */
  export const awaited = async (
    userId: UserId,
    format: ReleaseFormat,
    now = new Date(),
  ): Promise<AwaitedEditionView[]> =>
    inShelfOrder((await awaitedOf(userId, now)).filter((view) => view.format === format))

  /** The hourly pass's share: every edition anybody awaits whose watch was
   *  never looked up, then every one two weeks old, until the budget is spent;
   *  whatever is not reached goes first next hour. */
  export const watchDue = async (
    now = new Date(),
    budgetMs = SCHEDULED_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<{ watched: number; failed: number; deferred: number }> => {
    const overBudget = () => Date.now() - startedAt > budgetMs
    const all = await AwaitedEditionQuery.all()
    const watches = await AwaitedEditionQuery.watches(all.map((awaited) => awaited.watchKey))
    const due = dueWatchesOf(all, watches, now, todayOf(now))
    let watched = 0
    let failed = 0
    for (let start = 0; start < due.length; start += CALLS_AT_ONCE) {
      if (overBudget()) return { watched, failed, deferred: due.length - start }
      await Promise.all(
        due.slice(start, start + CALLS_AT_ONCE).map(async (awaited) => {
          try {
            await lookUp(seedOf(awaited), watches.get(awaited.watchKey), now)
            watched += 1
          } catch (error) {
            failed += 1
            logger.warn('edition lookup failed', { error, watchKey: awaited.watchKey })
          }
        }),
      )
    }
    return { watched, failed, deferred: 0 }
  }

  /** The morning pass's share: every edition awaited that came out, pushed to
   *  its reader once. No model is called; the hourly pass knows the dates. An
   *  edition found out too long ago is passed over silently. */
  export const sendAlerts = async (now = new Date()): Promise<{ readers: number }> => {
    const all = await AwaitedEditionQuery.all()
    const watches = await AwaitedEditionQuery.watches(all.map((awaited) => awaited.watchKey))
    const today = todayOf(now)
    const reached = new Set<UserId>()
    for (const awaited of all) {
      const view = viewOf(awaited, watches.get(awaited.watchKey), today)
      if (view.notifiedAt || view.state !== 'available') continue
      try {
        if (alertIsDue(view, today)) {
          await NotificationUseCase.notify(awaited.userId, {
            kind: 'translation',
            ...alertOf(view, awaited.language === 'fr' ? 'fr' : 'en'),
            link: 'shiori://discover',
          })
          reached.add(awaited.userId)
        }
        await AwaitedEditionCommand.markNotified(awaited, now)
      } catch (error) {
        logger.warn('edition alert failed', { error, userId: awaited.userId })
      }
    }
    return { readers: reached.size }
  }
}

/** Every edition the reader awaits, as it stands. The ones the library now
 *  holds — bought and brought in by the Audible sync, or added by hand — are
 *  no longer awaited, and go. */
const awaitedOf = async (userId: UserId, now: Date): Promise<AwaitedEditionView[]> => {
  const all = await AwaitedEditionQuery.byUser(userId)
  if (all.length === 0) return []
  const watches = await AwaitedEditionQuery.watches(all.map((awaited) => awaited.watchKey))
  const today = todayOf(now)
  const views = all.map((awaited) => viewOf(awaited, watches.get(awaited.watchKey), today))
  if (!views.some((view) => view.found)) return views
  const books = await BookQuery.all(userId)
  const held = views.filter((view) => isHeld(view, view.found, books))
  if (held.length === 0) return views
  await AwaitedEditionCommand.remove(
    userId,
    held.map((view) => view.id),
  )
  return views.filter((view) => !held.includes(view))
}

/** The book as the awaited edition remembers it. The reader's own photo is
 *  kept by its path, to be signed when drawn; a friend's never is. */
const sourceOf = (
  book: BookView,
  ownerId: UserId,
  userId: UserId,
  appLanguage: Language,
): AwaitedSource => {
  const covers = coverSourcesOf(book)
  return {
    bookId: book.id,
    ownerId,
    title: book.title,
    authors: book.authors,
    language: book.language ?? appLanguage,
    ...(book.series
      ? {
          series: {
            name: book.series.name,
            ...(book.series.volume !== undefined ? { volume: book.series.volume } : {}),
          },
        }
      : {}),
    ...(covers.publishedCoverUrl ? { coverUrl: covers.publishedCoverUrl } : {}),
    ...(covers.coverPath && ownerId === userId ? { coverPath: covers.coverPath } : {}),
  }
}

type WatchSeed = Omit<EditionWatch, 'checkedAt' | 'found'>

const seedOf = ({ watchKey, source, format, language }: AwaitedEdition): WatchSeed => ({
  key: watchKey,
  title: source.title,
  ...(source.authors[0] ? { author: source.authors[0] } : {}),
  originalLanguage: source.language,
  ...(source.series ? { series: source.series } : {}),
  format,
  language,
})

/** Look one edition up on the web and keep what was found, confirmed by the
 *  store that sells it. A week that finds nothing keeps what an earlier one
 *  found: the web forgets an announcement more often than it retracts one. */
const lookUp = async (
  seed: WatchSeed,
  previous: EditionWatch | undefined,
  now: Date,
): Promise<EditionWatch> => {
  const { value, usage } = await generate<EditionOutput>({
    step: 'awaited-edition',
    parts: [{ text: editionPrompt(seed, todayOf(now)) }],
    responseSchema: EDITION_SCHEMA,
    grounded: true,
  })
  if (usage)
    try {
      await AdminCommand.recordDiscoveryUsage(usage)
    } catch (error) {
      logger.warn('edition usage not recorded', { error })
    }
  const raw = editionFrom(value)
  const found = raw
    ? seed.format === 'audiobook'
      ? await DiscoveryUseCase.confirmedRecording(raw, previous?.found, seed.language)
      : await DiscoveryUseCase.confirmedPrinting(raw, previous?.found, seed.language)
    : previous?.found
  const watch: EditionWatch = { ...seed, checkedAt: now, ...(found ? { found } : {}) }
  await AwaitedEditionCommand.saveWatch(watch)
  return watch
}
