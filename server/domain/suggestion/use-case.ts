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
  SHOWN_COUNT,
  shouldGenerate,
  shownOf,
  tasteDigestOf,
} from './business-rules'
import { SuggestionCommand } from './command'
import { catalogueEntryOf } from './infrastructure/catalogue'
import { ask, isConfigured } from './infrastructure/claude'
import { suggestionsOf } from './parsing'
import { suggestionsPrompt } from './prompts'
import { SuggestionQuery } from './query'
import type { Dismissal, MonthlyDiscoveries, Suggestion, SuggestionView } from './types'

const logger = createLogger('suggestion')

/** How many catalogue checks run at once: twenty suggestions, two free
 *  catalogues, without hammering either. */
const CHECKS_AT_ONCE = 5

export namespace SuggestionUseCase {
  /** The month's discoveries: the first five suggestions the reader neither
   *  holds, dismissed nor awaits, in one format and the app's language. The
   *  model is asked first when the month has none yet, or too few are left —
   *  never twice a day — which takes about forty seconds; a failure keeps the
   *  selection there was. Empty, and nothing asked, without an Anthropic key. */
  export const monthly = async (
    userId: UserId,
    format: ReleaseFormat,
    appLanguage: Language,
    now = new Date(),
  ): Promise<MonthlyDiscoveries> => {
    const month = monthOf(now)
    if (!isConfigured()) return { month, suggestions: [] }
    const [books, opinions, dismissals, queue, awaited] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
      SuggestionQuery.dismissals(userId),
      SuggestionQuery.queue(userId),
      AwaitedEditionQuery.byUser(userId),
    ])
    const dismissed = new Set(dismissals.map((dismissal) => dismissal.key))
    const awaitedKeys = new Set(awaited.map((edition) => edition.watchKey))
    const isAwaited = (suggestion: Suggestion) =>
      RELEASE_FORMATS.some((candidate) =>
        awaitedKeys.has(watchKeyOf(suggestion, candidate, appLanguage)),
      )
    const remaining = shownOf(queue?.suggestions ?? [], books, dismissed).filter(
      (suggestion) => !isAwaited(suggestion),
    )
    const mayGenerate = (current: typeof queue) => shouldGenerate(current, remaining.length, now)
    // A new month starts afresh; a refill within the month keeps what is left
    // first. A failed generation keeps the selection there was.
    let suggestions = remaining
    if (
      mayGenerate(queue) &&
      (await SuggestionCommand.claimGeneration(userId, mayGenerate, now, month))
    ) {
      const answered = await generated(books, opinions, dismissals, appLanguage)
      if (answered) {
        const kept = queue?.month === month ? remaining : []
        const fresh = shownOf(answered, books, dismissed).filter(
          (suggestion) =>
            !isAwaited(suggestion) && !kept.some((known) => known.key === suggestion.key),
        )
        suggestions = [...kept, ...fresh]
        await SuggestionCommand.saveQueue({ userId, month, generatedAt: now, suggestions })
      }
    }
    return {
      month,
      suggestions: await viewsOf(suggestions.slice(0, SHOWN_COUNT), {
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

  export const dismiss = (userId: UserId, key: string) => SuggestionCommand.dismiss(userId, key)
}

/** The model's suggestions for this library, each checked against the
 *  catalogues — one neither knows is taken for an invention and left out —
 *  and given the cover one found. Undefined when the model failed. */
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
    const checked: (Suggestion | undefined)[] = []
    for (let start = 0; start < answered.length; start += CHECKS_AT_ONCE) {
      checked.push(
        ...(await Promise.all(
          answered.slice(start, start + CHECKS_AT_ONCE).map(async (suggestion) => {
            const entry = await catalogueEntryOf(
              suggestion.originalTitle,
              suggestion.authors[0] ?? '',
            )
            if (entry.known === false) {
              logger.info('suggestion unknown to the catalogues, left out', {
                title: suggestion.originalTitle,
                author: suggestion.authors[0],
              })
              return undefined
            }
            return entry.coverUrl ? { ...suggestion, coverUrl: entry.coverUrl } : suggestion
          }),
        )),
      )
    }
    return checked.filter((suggestion): suggestion is Suggestion => suggestion !== undefined)
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
      references: referencesOf(suggestion, [...context.books], context.opinions),
    }
  })
}
