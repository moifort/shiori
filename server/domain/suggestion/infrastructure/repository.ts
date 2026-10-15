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
  month: string,
  language: Language,
): Promise<boolean> =>
  transactionally(async (tx) => {
    const ref = queues().doc(userId)
    const queue = (await tx.get(ref)).data()
    if (!mayGenerate(queue)) return false
    tx.set(ref, {
      userId,
      month: queue?.month ?? month,
      language: queue?.language ?? language,
      generatedAt: now,
      suggestions: queue?.suggestions ?? [],
    })
    return true
  })

export const findDismissals = async (userId: UserId): Promise<Dismissal[]> =>
  (await dismissals().where('userId', '==', userId).get()).docs.map((doc) => doc.data())

export const saveDismissal = async (dismissal: Dismissal): Promise<void> => {
  await dismissals().doc(`${dismissal.userId}~${dismissal.key}`).set(dismissal)
}
