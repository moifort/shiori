import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { monthOf } from './business-rules'
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
    const position = queue?.suggestions.findIndex((candidate) => candidate.key === key) ?? -1
    const suggestion = queue?.suggestions[position]
    if (!queue || !suggestion) return 'not-found' as const
    const dismissal: Dismissal = {
      userId,
      key,
      title: suggestion.title,
      authors: suggestion.authors,
      reason,
      dismissedAt: now,
      suggestion,
      position,
    }
    await repository.saveDismissal(dismissal)
    await repository.saveQueue({
      ...queue,
      suggestions: queue.suggestions.filter((candidate) => candidate.key !== key),
    })
    return dismissal
  }

  /** A dismissal taken back: the book may be suggested again, the model no
   *  longer told of it, and, turned down this month, it returns to the line
   *  where it stood. Not-found when the reader turned down no such book. */
  export const reconsider = async (userId: UserId, key: string) => {
    const dismissal = await repository.findDismissal(userId, key)
    if (!dismissal) return 'not-found' as const
    await repository.deleteDismissal(userId, key)
    const queue = await repository.findQueue(userId)
    const { suggestion, position } = dismissal
    if (
      queue &&
      suggestion &&
      queue.month === monthOf(dismissal.dismissedAt) &&
      !queue.suggestions.some((candidate) => candidate.key === key)
    ) {
      const suggestions = [...queue.suggestions]
      suggestions.splice(
        Math.min(position ?? suggestions.length, suggestions.length),
        0,
        suggestion,
      )
      await repository.saveQueue({ ...queue, suggestions })
    }
    return 'reconsidered' as const
  }
}
