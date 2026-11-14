import {
  awaitableFormatsOf,
  editionWatchKeyOf,
  stateOf,
} from '~/domain/awaited-edition/business-rules'
import { AwaitedEditionQuery } from '~/domain/awaited-edition/query'
import type { AwaitedEditionId } from '~/domain/awaited-edition/types'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { todayOf } from '~/domain/discovery/business-rules'
import { RELEASE_FORMATS, type ReleaseFormat } from '~/domain/discovery/types'
import { wantsAlert } from '~/domain/notification/business-rules'
import { NotificationQuery } from '~/domain/notification/query'
import { NotificationUseCase } from '~/domain/notification/use-case'
import { watchOf } from '~/domain/release/business-rules'
import { ReleaseQuery } from '~/domain/release/query'
import type { ReleaseView } from '~/domain/release/types'
import { type DescribeRefusal, ReleaseUseCase } from '~/domain/release/use-case'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import {
  discoveriesAlertOf,
  monthOf,
  readerProfileOf,
  referencesOf,
  releaseIdentityOf,
  releaseShownOf,
  shouldGenerate,
  shownOf,
  statusOf,
  tasteDigestOf,
} from '~/domain/suggestion/business-rules'
import { SuggestionCommand } from '~/domain/suggestion/command'
import { coverOf } from '~/domain/suggestion/infrastructure/catalogue'
import { ask, isConfigured } from '~/domain/suggestion/infrastructure/claude'
import { suggestionsOf } from '~/domain/suggestion/parsing'
import { suggestionsPrompt } from '~/domain/suggestion/prompts'
import { SuggestionQuery } from '~/domain/suggestion/query'
import type {
  Dismissal,
  DismissalReason,
  MonthlyDiscoveries,
  Suggestion,
  SuggestionQueue,
  SuggestionView,
} from '~/domain/suggestion/types'
import { WishQuery } from '~/domain/wish/query'
import type { Wish } from '~/domain/wish/types'
import { createLogger } from '~/system/logger'
import { withRequestCacheScope } from '~/system/request-cache'

const logger = createLogger('suggestion')

/** How many cover lookups run at once: twenty suggestions, without hammering
 *  Open Library. */
const LOOKUPS_AT_ONCE = 5

export namespace SuggestionUseCase {
  /** The month's discoveries: every suggestion of the month's selection the
   *  reader neither holds, wished for, dismissed nor awaits, in one format and the app's
   *  language, and where the selection stands. Only Découvrir asks for a
   *  selection to be made — `lookUp` — when the reader has none for this
   *  month, or one in another language, never twice a day: that takes about a
   *  minute. A look while another is making it answers `searching`, for the
   *  app to ask again; a failure answers `none` and is tried the next day. The
   *  home page only reads what there is. A selection that ran out is `ready`
   *  and empty until next month. `none`, and nothing asked, without an
   *  Anthropic key. `needsRatings` when the library gives the model nothing to
   *  go on: no selection is made until the reader rates a book. */
  export const monthly = async (
    userId: UserId,
    format: ReleaseFormat,
    appLanguage: Language,
    lookUp: boolean,
    now = new Date(),
  ): Promise<MonthlyDiscoveries> => {
    const month = monthOf(now)
    if (!isConfigured()) return { month, status: 'none', suggestions: [], needsRatings: false }
    const [library, queue] = await Promise.all([libraryOf(userId), SuggestionQuery.queue(userId)])
    const { books, opinions, dismissals, awaited } = library
    const mayGenerate = (current: typeof queue) => shouldGenerate(current, now, appLanguage)
    let suggestions = queue?.month === month ? keptOf(queue.suggestions, library, appLanguage) : []
    let status = statusOf(queue, now, appLanguage)
    if (
      lookUp &&
      mayGenerate(queue) &&
      (await SuggestionCommand.claimGeneration(userId, mayGenerate, now, appLanguage))
    ) {
      const selection = await newSelection(userId, library, appLanguage, now)
      if (selection) {
        suggestions = selection
        status = 'ready'
      } else {
        status = queue?.month === month ? 'ready' : 'none'
      }
    }
    return {
      month,
      status,
      suggestions: await viewsOf(suggestions, {
        userId,
        format,
        appLanguage,
        now,
        books,
        opinions,
        awaited,
      }),
      needsRatings: !tasteDigestOf(books, opinions, dismissals),
    }
  }

  /** Describe one of the month's discoveries for its page, as its release, in
   *  one format and the app's language: `not-found` for one the reader is not
   *  shown this month. */
  export const describe = async (
    userId: UserId,
    key: string,
    format: ReleaseFormat,
    appLanguage: Language,
    now = new Date(),
  ): Promise<ReleaseView | DescribeRefusal | 'not-found'> => {
    const { suggestions } = await monthly(userId, format, appLanguage, false, now)
    const view = suggestions.find((candidate) => candidate.suggestion.key === key)
    if (!view) return 'not-found'
    return ReleaseUseCase.describeShown(
      userId,
      releaseIdentityOf(view),
      releaseShownOf(view),
      appLanguage,
      now,
    )
  }

  export const dismiss = (userId: UserId, key: string, reason: DismissalReason, now = new Date()) =>
    SuggestionCommand.dismiss(userId, key, reason, now)

  export const reconsider = (userId: UserId, key: string) =>
    SuggestionCommand.reconsider(userId, key)

  /** The first of the month's pass, called by Cloud Scheduler: every reader
   *  who left the alert on with a device to hear it is told the month's
   *  discoveries are made, once. A reader who had a selection before and has
   *  none for this month is given it first, in the language of their last
   *  ones; one whose selection Découvrir already made — opened after midnight,
   *  before the pass — is told without the model being asked. The others are
   *  given theirs when they open Découvrir, as before: nobody is asked for
   *  whom the model would be paid with nothing to say.
   *
   *  A generation takes a minute or two, so a run makes a few at once and
   *  leaves the rest to the next run; a reader whose generation failed is
   *  given theirs the day after, or by Découvrir. Answers the counts. */
  export const generateForEveryReader = async (
    now = new Date(),
  ): Promise<{ due: number; told: number }> => {
    if (!isConfigured()) return { due: 0, told: 0 }
    const month = monthOf(now)
    const mayGenerate = (queue: SuggestionQueue | undefined, language: Language) =>
      queue !== undefined && queue.month !== month && shouldGenerate(queue, now, language)
    const mayTell = (queue: SuggestionQueue) =>
      queue.month === month &&
      queue.toldMonth !== month &&
      queue.generatingSince === undefined &&
      queue.suggestions.length > 0
    const hearing = async (queues: SuggestionQueue[]) =>
      (
        await Promise.all(
          queues.map(async (queue) =>
            wantsAlert(await NotificationQuery.settings(queue.userId, now), 'discoveries')
              ? queue
              : undefined,
          ),
        )
      ).filter((queue) => queue !== undefined)
    const tell = async (userId: UserId, language: Language) => {
      const delivery = await NotificationUseCase.notify(userId, {
        kind: 'discoveries',
        ...discoveriesAlertOf(language),
        link: 'shiori://discover',
      })
      if (delivery !== 'delivered') return false
      await SuggestionCommand.markTold(userId, month)
      return true
    }
    const queues = await SuggestionQuery.all()
    const due = await hearing(queues.filter((queue) => mayGenerate(queue, queue.language)))
    const made = await hearing(queues.filter(mayTell))
    const generated = await Promise.all(
      due.slice(0, READERS_PER_PASS).map(async ({ userId, language }) => {
        try {
          const claimed = await SuggestionCommand.claimGeneration(
            userId,
            (queue) => mayGenerate(queue, language),
            now,
            language,
          )
          if (!claimed) return false
          // Read in a scope of its own: the library is not kept until the pass ends.
          const library = await withRequestCacheScope(() => libraryOf(userId))
          const selection = await newSelection(userId, library, language, now)
          if (!selection || selection.length === 0) return false
          return await tell(userId, language)
        } catch (error) {
          logger.warn('monthly discoveries pass failed', { error, userId })
          return false
        }
      }),
    )
    const reminded = await Promise.all(
      made.map(async ({ userId, language }) => {
        try {
          return await tell(userId, language)
        } catch (error) {
          logger.warn('monthly discoveries alert failed', { error, userId })
          return false
        }
      }),
    )
    return {
      due: due.length + made.length,
      told: [...generated, ...reminded].filter(Boolean).length,
    }
  }
}

/** How many readers one run of the monthly pass makes a selection for, at
 *  once: each is a minute or two of the model, inside the function's three. */
const READERS_PER_PASS = 5

type Library = {
  books: Book[]
  opinions: SeriesOpinion[]
  dismissals: Dismissal[]
  awaited: Awaited<ReturnType<typeof AwaitedEditionQuery.byUser>>
  wishes: Wish[]
}

/** What the selection is made from and checked against. */
const libraryOf = async (userId: UserId): Promise<Library> => {
  const [books, opinions, dismissals, awaited, wishes] = await Promise.all([
    BookQuery.all(userId),
    SeriesOpinionQuery.all(userId),
    SuggestionQuery.dismissals(userId),
    AwaitedEditionQuery.byUser(userId),
    WishQuery.byUser(userId),
  ])
  return { books, opinions, dismissals, awaited, wishes }
}

/** The suggestions the reader neither holds, dismissed nor awaits in any
 *  format. */
const keptOf = (
  candidates: readonly Suggestion[],
  { books, dismissals, awaited, wishes }: Library,
  language: Language,
): Suggestion[] => {
  const dismissed = new Set(dismissals.map((dismissal) => dismissal.key))
  const awaitedKeys = new Set(awaited.map((edition) => edition.watchKey))
  // A book on the wishlist has had its answer, as one on the shelf has.
  return shownOf(candidates, [...books, ...wishes], dismissed).filter(
    (suggestion) =>
      !RELEASE_FORMATS.some((candidate) =>
        awaitedKeys.has(watchKeyOf(suggestion, candidate, language)),
      ),
  )
}

/** The model asked for the month's selection, once the generation is
 *  claimed: saved as the reader's queue, or the claim let go when the model
 *  failed, and undefined. */
const newSelection = async (
  userId: UserId,
  library: Library,
  language: Language,
  now: Date,
): Promise<Suggestion[] | undefined> => {
  const answered = await generated(library.books, library.opinions, library.dismissals, language)
  if (!answered) {
    await SuggestionCommand.endGeneration(userId)
    return undefined
  }
  const suggestions = keptOf(answered, library, language)
  await SuggestionCommand.saveQueue({
    userId,
    month: monthOf(now),
    language,
    generatedAt: now,
    suggestions,
  })
  return suggestions
}

/** The model's suggestions for this library, each given the cover Open
 *  Library has. None is left out for a catalogue not knowing it: the 2026-10-12
 *  test found no invented book, and Open Library misses real ones. Undefined
 *  when the model failed, or was not asked: a library with nothing ranked,
 *  dropped or dismissed gives it nothing to go on, and it answers asking for
 *  the list instead of suggesting. */
const generated = async (
  books: readonly Book[],
  opinions: readonly SeriesOpinion[],
  dismissals: readonly Dismissal[],
  appLanguage: Language,
): Promise<Suggestion[] | undefined> => {
  const digest = tasteDigestOf(books, opinions, dismissals)
  if (!digest) return undefined
  try {
    const prompt = suggestionsPrompt(digest, readerProfileOf(books), appLanguage)
    const answered = suggestionsOf(await ask(prompt))
    const covered: Suggestion[] = []
    for (let start = 0; start < answered.length; start += LOOKUPS_AT_ONCE) {
      covered.push(
        ...(await Promise.all(
          answered.slice(start, start + LOOKUPS_AT_ONCE).map(async (suggestion) => {
            const coverUrl = await coverOf(suggestion.originalTitle, suggestion.authors[0] ?? '')
            return coverUrl ? { ...suggestion, coverUrl } : suggestion
          }),
        )),
      )
    }
    return covered
  } catch (error) {
    logger.error('discoveries not generated', { error })
    return undefined
  }
}

/** The shared watch a suggestion's edition in one format and language is kept
 *  under: the one an edition awaited from its page uses. */
const watchKeyOf = (suggestion: Suggestion, format: ReleaseFormat, language: Language) =>
  editionWatchKeyOf(
    { title: suggestion.originalTitle, authors: suggestion.authors },
    format,
    language,
  )

type Context = {
  userId: UserId
  format: ReleaseFormat
  appLanguage: Language
  now: Date
  books: readonly Book[]
  opinions: readonly SeriesOpinion[]
  awaited: readonly { watchKey: string; id: AwaitedEditionId }[]
}

/** The rows as the reader sees them: where each edition stands, the formats
 *  it may still be awaited in, the cover its page found, its references. */
const viewsOf = async (
  suggestions: readonly Suggestion[],
  context: Context,
): Promise<SuggestionView[]> => {
  if (suggestions.length === 0) return []
  const { format, appLanguage, now } = context
  const keys = suggestions.flatMap((suggestion) =>
    RELEASE_FORMATS.map((candidate) => watchKeyOf(suggestion, candidate, appLanguage)),
  )
  const releases = await ReleaseQuery.byKeys(keys)
  const watchAt = (key: string) => watchOf(releases.get(key))
  const awaitedByKey = new Map(context.awaited.map((edition) => [edition.watchKey, edition.id]))
  const today = todayOf(now)
  // The covers of the books cited, signed once for every row: a photo's URL
  // is signed per request.
  const referencesBySuggestion = new Map(
    suggestions.map((suggestion) => [
      suggestion.key,
      referencesOf(suggestion, [...context.books], context.opinions),
    ]),
  )
  const cited = new Set(
    [...referencesBySuggestion.values()].flat().map((reference) => reference.bookId),
  )
  const covers = new Map(
    (await BookQuery.withSignedCovers(context.books.filter((book) => cited.has(book.id)))).flatMap(
      (book) => (book.coverUrl ? [[book.id, book.coverUrl as string] as const] : []),
    ),
  )
  return suggestions.map((suggestion) => {
    const watchKey = watchKeyOf(suggestion, format, appLanguage)
    const watch = watchAt(watchKey)
    const awaitedId = awaitedByKey.get(watchKey)
    return {
      suggestion,
      format,
      language: appLanguage,
      watchKey,
      ...(watch ? { watch } : {}),
      state: stateOf(watch?.found, format, today),
      awaitableFormats: awaitableFormatsOf(
        { language: suggestion.language, format: 'book' },
        appLanguage,
      ).filter((candidate) => {
        const key = watchKeyOf(suggestion, candidate, appLanguage)
        return (
          stateOf(watchAt(key)?.found, candidate, today) !== 'available' && !awaitedByKey.has(key)
        )
      }),
      ...(awaitedId ? { awaitedId } : {}),
      references: (referencesBySuggestion.get(suggestion.key) ?? []).map((reference) => {
        const coverUrl = covers.get(reference.bookId)
        return coverUrl ? { ...reference, coverUrl } : reference
      }),
    }
  })
}
