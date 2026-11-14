import type { AwardDismissal, FoundWinners } from '~/domain/award/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { deleteAllOwnedBy, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// Shared, naming nobody: one document per award and year the daily pass found
// after the versioned list — a handful a year.
const awardWinners = () =>
  db().collection('award-winners').withConverter(genericDataConverter<FoundWinners>())

export const findAllWinners = async (): Promise<FoundWinners[]> =>
  (await awardWinners().get()).docs.map((doc) => doc.data())

export const saveWinners = async (found: FoundWinners): Promise<void> => {
  await awardWinners().doc(found.key).set(withoutAbsentFields(found))
}

// Private: one document per reader and novel turned down.
const dismissals = () =>
  db().collection('award-dismissals').withConverter(genericDataConverter<AwardDismissal>())

export const findDismissals = async (userId: UserId): Promise<AwardDismissal[]> =>
  (await dismissals().where('userId', '==', userId).get()).docs.map((doc) => doc.data())

export const saveDismissal = async (dismissal: AwardDismissal): Promise<void> => {
  await dismissals().doc(`${dismissal.userId}~${dismissal.key}`).set(withoutAbsentFields(dismissal))
}

export const deleteDismissal = async (userId: UserId, key: string): Promise<void> => {
  await dismissals().doc(`${userId}~${key}`).delete()
}

export const removeAllByUser = (userId: UserId): Promise<void> =>
  deleteAllOwnedBy(dismissals(), userId)
