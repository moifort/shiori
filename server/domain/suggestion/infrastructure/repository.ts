import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import {
  deleteInBatches,
  genericDataConverter,
  transactionally,
  withoutAbsentFields,
} from '~/utils/firestore'
import type { Dismissal, Suggestion, SuggestionQueue } from '../types'

// One document per reader, whose id IS the userId: the month's selection.
const queues = () =>
  db().collection('suggestion-queues').withConverter(genericDataConverter<SuggestionQueue>())

// Flat, one document per reader and book: what they said "Pas intéressé" to.
const dismissals = () =>
  db().collection('suggestion-dismissals').withConverter(genericDataConverter<Dismissal>())

export const findQueue = async (userId: UserId): Promise<SuggestionQueue | undefined> =>
  (await queues().doc(userId).get()).data()

/** Every reader's selection, whatever its month: the monthly pass picks the
 *  readers it renews from them. */
export const allQueues = async (): Promise<SuggestionQueue[]> =>
  (await queues().get()).docs.map((doc) => doc.data())

/** Rewrite the reader's selection from what is stored when the transaction
 *  runs, never from a copy read earlier: a selection made, a reader told or a
 *  suggestion dismissed meanwhile is kept. `revise` answers undefined to write
 *  nothing. */
export const reviseQueue = async (
  userId: UserId,
  revise: (queue: SuggestionQueue | undefined) => SuggestionQueue | undefined,
): Promise<SuggestionQueue | undefined> =>
  transactionally(async (tx) => {
    const ref = queues().doc(userId)
    const revised = revise((await tx.get(ref)).data())
    if (revised) tx.set(ref, withoutAbsentFields(revised))
    return revised
  })

/** Take a suggestion out of the selection as it stands and keep the dismissal
 *  that can put it back, in one transaction. Undefined when the selection
 *  holds no such suggestion. */
export const dismissFromQueue = async (
  userId: UserId,
  key: string,
  dismissalOf: (suggestion: Suggestion, position: number) => Dismissal,
): Promise<Dismissal | undefined> =>
  transactionally(async (tx) => {
    const ref = queues().doc(userId)
    const queue = (await tx.get(ref)).data()
    const position = queue?.suggestions.findIndex((candidate) => candidate.key === key) ?? -1
    const suggestion = queue?.suggestions[position]
    if (!queue || !suggestion) return undefined
    const dismissal = dismissalOf(suggestion, position)
    tx.set(dismissals().doc(`${userId}~${key}`), withoutAbsentFields(dismissal))
    tx.set(
      ref,
      withoutAbsentFields({
        ...queue,
        suggestions: queue.suggestions.filter((candidate) => candidate.key !== key),
      }),
    )
    return dismissal
  })

/** Claims the day's generation: true when this caller may ask the model, the
 *  queue's date stamped in the same transaction so a second caller — the home
 *  page and Découvrir load together — finds it taken. */
export const claimGeneration = async (
  userId: UserId,
  mayGenerate: (queue: SuggestionQueue | undefined) => boolean,
  now: Date,
  language: Language,
): Promise<boolean> =>
  transactionally(async (tx) => {
    const ref = queues().doc(userId)
    const queue = (await tx.get(ref)).data()
    if (!mayGenerate(queue)) return false
    // The month and its suggestions stay what they were until the new
    // selection is saved: only the date and the mark of the search change.
    tx.set(
      ref,
      withoutAbsentFields({
        userId,
        month: queue?.month ?? '',
        language: queue?.language ?? language,
        generatedAt: now,
        generatingSince: now,
        suggestions: queue?.suggestions ?? [],
        ...(queue?.toldMonth ? { toldMonth: queue.toldMonth } : {}),
      }),
    )
    return true
  })

/** The reader was told the month's discoveries were made. */
export const markTold = async (userId: UserId, month: string): Promise<void> =>
  transactionally(async (tx) => {
    const ref = queues().doc(userId)
    const queue = (await tx.get(ref)).data()
    if (!queue) return
    tx.set(ref, withoutAbsentFields({ ...queue, toldMonth: month }))
  })

/** The search failed: its mark is taken off, the selection left as it was. */
export const endGeneration = async (userId: UserId): Promise<void> =>
  transactionally(async (tx) => {
    const ref = queues().doc(userId)
    const queue = (await tx.get(ref)).data()
    if (!queue) return
    const { generatingSince: _, ...rest } = queue
    tx.set(ref, withoutAbsentFields(rest))
  })

export const findDismissals = async (userId: UserId): Promise<Dismissal[]> =>
  (await dismissals().where('userId', '==', userId).get()).docs.map((doc) => doc.data())

export const saveDismissal = async (dismissal: Dismissal): Promise<void> => {
  await dismissals().doc(`${dismissal.userId}~${dismissal.key}`).set(withoutAbsentFields(dismissal))
}

export const findDismissal = async (userId: UserId, key: string): Promise<Dismissal | undefined> =>
  (await dismissals().doc(`${userId}~${key}`).get()).data()

export const deleteDismissal = async (userId: UserId, key: string): Promise<void> => {
  await dismissals().doc(`${userId}~${key}`).delete()
}

/** The reader's selection and every "Pas intéressé" they said (account deletion). */
export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await dismissals().where('userId', '==', userId).get()
  await deleteInBatches([queues().doc(userId), ...snapshot.docs.map((doc) => doc.ref)])
}
