import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { genericDataConverter, transactionally } from '~/utils/firestore'
import type { Dismissal, SuggestionQueue } from '../types'

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

export const saveQueue = async (queue: SuggestionQueue): Promise<void> => {
  await queues().doc(queue.userId).set(queue)
}

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
    tx.set(ref, {
      userId,
      month: queue?.month ?? '',
      language: queue?.language ?? language,
      generatedAt: now,
      generatingSince: now,
      suggestions: queue?.suggestions ?? [],
    })
    return true
  })

/** The search failed: its mark is taken off, the selection left as it was. */
export const endGeneration = async (userId: UserId): Promise<void> =>
  transactionally(async (tx) => {
    const ref = queues().doc(userId)
    const queue = (await tx.get(ref)).data()
    if (!queue) return
    const { generatingSince: _, ...rest } = queue
    tx.set(ref, rest)
  })

export const findDismissals = async (userId: UserId): Promise<Dismissal[]> =>
  (await dismissals().where('userId', '==', userId).get()).docs.map((doc) => doc.data())

export const saveDismissal = async (dismissal: Dismissal): Promise<void> => {
  await dismissals().doc(`${dismissal.userId}~${dismissal.key}`).set(dismissal)
}
