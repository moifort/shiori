import type { AwardDismissal, FoundWinners } from '~/domain/award/types'
import { db } from '~/system/firebase'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'
import { oneDocumentPerReaderAndKey } from '~/utils/reader-documents'

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
const dismissals = oneDocumentPerReaderAndKey({
  collection: () =>
    db().collection('award-dismissals').withConverter(genericDataConverter<AwardDismissal>()),
  keyOf: (dismissal) => dismissal.key,
})

export const {
  findAllByUser: findDismissals,
  save: saveDismissal,
  remove: removeDismissal,
  removeAllByUser,
} = dismissals
