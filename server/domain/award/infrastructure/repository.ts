import type { AwardInterest } from '~/domain/award/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'

// Shared, naming nobody: one document per genre and language somebody looked
// at, so the hourly pass watches only the winners somebody may see.
const awardInterests = () =>
  db().collection('award-interests').withConverter(genericDataConverter<AwardInterest>())

export const findInterest = async (key: string): Promise<AwardInterest | undefined> =>
  (await awardInterests().doc(key).get()).data()

export const findAllInterests = async (): Promise<AwardInterest[]> =>
  (await awardInterests().get()).docs.map((doc) => doc.data())

export const saveInterest = async (interest: AwardInterest): Promise<void> => {
  await awardInterests().doc(interest.key).set(interest)
}
