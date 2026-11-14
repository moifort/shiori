import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { monthOf } from './business-rules'
import * as repository from './infrastructure/repository'
import type { Dismissal, DismissalReason, SuggestionQueue } from './types'

export namespace SuggestionCommand {
  /** Keep the selection just made, over the one stored: the month the reader
   *  was last told of stays, or the first-of-the-month alert would go twice. */
  export const saveQueue = async (queue: SuggestionQueue): Promise<void> => {
    await repository.reviseQueue(queue.userId, (stored) =>
      stored?.toldMonth && !queue.toldMonth ? { ...queue, toldMonth: stored.toldMonth } : queue,
    )
  }

  export const claimGeneration = (
    userId: UserId,
    mayGenerate: (queue: SuggestionQueue | undefined) => boolean,
    now: Date,
    language: Language,
  ) => repository.claimGeneration(userId, mayGenerate, now, language)

  export const markTold = (userId: UserId, month: string) => repository.markTold(userId, month)

  export const endGeneration = (userId: UserId) => repository.endGeneration(userId)

  /** "Pas intéressé" or "Je n'aime pas": the suggestion leaves the queue for
   *  good. Not-found when the queue holds no such suggestion. */
  export const dismiss = async (
    userId: UserId,
    key: string,
    reason: DismissalReason,
    now = new Date(),
  ) =>
    (await repository.dismissFromQueue(
      userId,
      key,
      (suggestion, position): Dismissal => ({
        userId,
        key,
        title: suggestion.title,
        authors: suggestion.authors,
        reason,
        dismissedAt: now,
        suggestion,
        position,
      }),
    )) ?? ('not-found' as const)

  /** A dismissal taken back: the book may be suggested again, the model no
   *  longer told of it, and, turned down this month, it returns to the line
   *  where it stood. Not-found when the reader turned down no such book. */
  export const reconsider = async (userId: UserId, key: string) => {
    const dismissal = await repository.findDismissal(userId, key)
    if (!dismissal) return 'not-found' as const
    await repository.removeDismissal(userId, key)
    const { suggestion, position } = dismissal
    if (suggestion)
      await repository.reviseQueue(userId, (queue) => {
        if (
          !queue ||
          queue.month !== monthOf(dismissal.dismissedAt) ||
          queue.suggestions.some((candidate) => candidate.key === key)
        )
          return undefined
        const suggestions = [...queue.suggestions]
        suggestions.splice(
          Math.min(position ?? suggestions.length, suggestions.length),
          0,
          suggestion,
        )
        return { ...queue, suggestions }
      })
    return 'reconsidered' as const
  }

  /** The reader's selection and every book they turned down (account deletion). */
  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
