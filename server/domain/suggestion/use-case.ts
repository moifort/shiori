import {
  awaitableFormatsOf,
  editionWatchKeyOf,
  stateOf,
} from '~/domain/awaited-edition/business-rules'
import { AwaitedEditionQuery } from '~/domain/awaited-edition/query'
import type { AwaitedEditionId, EditionWatch } from '~/domain/awaited-edition/types'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { releaseDescriptionKeyOf, todayOf } from '~/domain/discovery/business-rules'
import { DiscoveryQuery } from '~/domain/discovery/query'
import { RELEASE_FORMATS, type ReleaseFormat } from '~/domain/discovery/types'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import {
  monthOf,
  readerProfileOf,
  referencesOf,
  shouldGenerate,
  shownOf,
  statusOf,
  tasteDigestOf,
} from './business-rules'
import { SuggestionCommand } from './command'
import { coverOf } from './infrastructure/catalogue'
import { ask, isConfigured } from './infrastructure/claude'
import { suggestionsOf } from './parsing'
import { suggestionsPrompt } from './prompts'
import { SuggestionQuery } from './query'
import type {
  Dismissal,
  DismissalReason,
  MonthlyDiscoveries,
  Suggestion,
  SuggestionView,
} from './types'

const logger = createLogger('suggestion')

/** How many cover lookups run at once: twenty suggestions, without hammering
 *  Open Library. */
const LOOKUPS_AT_ONCE = 5

export namespace SuggestionUseCase {
  /** The month's discoveries: every suggestion of the month's selection the
   *  reader neither holds, dismissed nor awaits, in one format and the app's
   *  language, and where the selection stands. Only Découvrir asks for a
   *  selection to be made — `lookUp` — when the reader has none for this
   *  month, or one in another language, never twice a day: that takes about a
   *  minute. A look while another is making it answers `searching`, for the
   *  app to ask again; a failure answers `none` and is tried the next day. The
   *  home page only reads what there is. A selection that ran out is `ready`
   *  and empty until next month. `none`, and nothing asked, without an
   *  Anthropic key. */
  export const monthly = async (
    userId: UserId,
    format: ReleaseFormat,
    appLanguage: Language,
    lookUp: boolean,
    now = new Date(),
  ): Promise<MonthlyDiscoveries> => {
    const month = monthOf(now)
    if (!isConfigured()) return { month, status: 'none', suggestions: [] }
    const [books, opinions, dismissals, queue, awaited] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
      SuggestionQuery.dismissals(userId),
      SuggestionQuery.queue(userId),
      AwaitedEditionQuery.byUser(userId),
    ])
    const dismissed = new Set(dismissals.map((dismissal) => dismissal.key))
    const awaitedKeys = new Set(awaited.map((edition) => edition.watchKey))
    const shown = (candidates: readonly Suggestion[]) =>
      shownOf(candidates, books, dismissed).filter(
        (suggestion) =>
          !RELEASE_FORMATS.some((candidate) =>
            awaitedKeys.has(watchKeyOf(suggestion, candidate, appLanguage)),
          ),
      )
    const mayGenerate = (current: typeof queue) => shouldGenerate(current, now, appLanguage)
    let suggestions = queue?.month === month ? shown(queue.suggestions) : []
    let status = statusOf(queue, now, appLanguage)
    if (
      lookUp &&
      mayGenerate(queue) &&
      (await SuggestionCommand.claimGeneration(userId, mayGenerate, now, appLanguage))
    ) {
      const answered = await generated(books, opinions, dismissals, appLanguage)
      if (answered) {
        suggestions = shown(answered)
        status = 'ready'
        await SuggestionCommand.saveQueue({
          userId,
          month,
          language: appLanguage,
          generatedAt: now,
          suggestions,
        })
      } else {
        await SuggestionCommand.endGeneration(userId)
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
    }
  }

  export const dismiss = (userId: UserId, key: string, reason: DismissalReason) =>
    SuggestionCommand.dismiss(userId, key, reason)
}

/** The model's suggestions for this library, each given the cover Open
 *  Library has. None is left out for a catalogue not knowing it: the 2026-10-12
 *  test found no invented book, and Open Library misses real ones. Undefined
 *  when the model failed. */
const generated = async (
  books: readonly Book[],
  opinions: readonly SeriesOpinion[],
  dismissals: readonly Dismissal[],
  appLanguage: Language,
): Promise<Suggestion[] | undefined> => {
  try {
    const prompt = suggestionsPrompt(
      tasteDigestOf(books, opinions, dismissals),
      readerProfileOf(books),
      appLanguage,
    )
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
  const describedKeyOf = (suggestion: Suggestion) =>
    releaseDescriptionKeyOf(
      {
        title: suggestion.title,
        authors: suggestion.authors,
        format,
        ...(suggestion.language !== appLanguage ? { language: suggestion.language } : {}),
      },
      appLanguage,
    )
  const [watches, described] = await Promise.all([
    AwaitedEditionQuery.watches(keys),
    DiscoveryQuery.descriptions(suggestions.map(describedKeyOf)),
  ])
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
    const watch: EditionWatch | undefined = watches.get(watchKey)
    const awaitedId = awaitedByKey.get(watchKey)
    const describedCoverUrl =
      described.get(describedKeyOf(suggestion))?.description.book.coverUrl ?? suggestion.coverUrl
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
          stateOf(watches.get(key)?.found, candidate, today) !== 'available' &&
          !awaitedByKey.has(key)
        )
      }),
      ...(awaitedId ? { awaitedId } : {}),
      ...(describedCoverUrl ? { describedCoverUrl } : {}),
      references: (referencesBySuggestion.get(suggestion.key) ?? []).map((reference) => {
        const coverUrl = covers.get(reference.bookId)
        return coverUrl ? { ...reference, coverUrl } : reference
      }),
    }
  })
}
