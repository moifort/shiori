import { FieldValue } from 'firebase-admin/firestore'
import { db } from '~/system/firebase'

// One document per month counts the grounded calls Gemini answered: the free
// searches are a monthly allowance, and Gemini under-reports the searches a
// call ran, so the calls are what can be counted. A global collection holding
// no user id, keyed by month; incremented without a read, as `ai-usage` is.
const groundingMonths = () => db().collection('grounding-months')

export const countGroundedCall = async (month: string): Promise<void> => {
  await groundingMonths()
    .doc(month)
    .set({ month, calls: FieldValue.increment(1) }, { merge: true })
}

export const findGroundedCalls = async (month: string): Promise<number> => {
  const doc = await groundingMonths().doc(month).get()
  return (doc.data()?.calls as number | undefined) ?? 0
}
