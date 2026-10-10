import type { FoundWinners } from '~/domain/award/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'

// Shared, naming nobody: one document per award and year the daily pass found
// after the versioned list — a handful a year.
const awardWinners = () =>
  db().collection('award-winners').withConverter(genericDataConverter<FoundWinners>())

export const findAllWinners = async (): Promise<FoundWinners[]> =>
  (await awardWinners().get()).docs.map((doc) => doc.data())

export const saveWinners = async (found: FoundWinners): Promise<void> => {
  await awardWinners().doc(found.key).set(found)
}
