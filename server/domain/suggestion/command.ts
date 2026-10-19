import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import * as repository from './infrastructure/repository'
import type { Dismissal, DismissalReason, SuggestionQueue } from './types'

export namespace SuggestionCommand {
  export const saveQueue = (queue: SuggestionQueue) => repository.saveQueue(queue)

  export const claimGeneration = (
    userId: UserId,
    mayGenerate: (queue: SuggestionQueue | undefined) => boolean,
    now: Date,
    language: Language,
  ) => repository.claimGeneration(userId, mayGenerate, now, language)

  export const endGeneration = (userId: UserId) => repository.endGeneration(userId)

  /** "Pas intéressé" or "Je n'aime pas": the suggestion leaves the queue for
   *  good. Not-found when the queue holds no such suggestion. */
  export const dismiss = async (
    userId: UserId,
    key: string,
    reason: DismissalReason,
    now = new Date(),
  ) => {
    const queue = await repository.findQueue(userId)
    const suggestion = queue?.suggestions.find((candidate) => candidate.key === key)
    if (!queue || !suggestion) return 'not-found' as const
    const dismissal: Dismissal = {
      userId,
      key,
      title: suggestion.title,
      authors: suggestion.authors,
      reason,
      dismissedAt: now,
    }
    await repository.saveDismissal(dismissal)
    await repository.saveQueue({
      ...queue,
      suggestions: queue.suggestions.filter((candidate) => candidate.key !== key),
    })
    return dismissal
  }
}
