import { FieldValue } from 'firebase-admin/firestore'
import { heldFormatOf } from '~/domain/scan/business-rules'
import type { CachedScan, ImageHash, ScanLanguage } from '~/domain/scan/types'
import { db } from '~/system/firebase'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// A global collection, like the series catalogue and for the same reason: a
// scanned cover is a fact about an image, not about whoever photographed it, so
// one entry serves every reader who scans the same edition. It holds no user id.
const cache = () => db().collection('scan-cache').withConverter(genericDataConverter<CachedScan>())

// Keyed by image AND language: the same cover scanned in two languages must not
// serve one language's synopsis to the other.
const docId = (imageHash: ImageHash, language: ScanLanguage) => `${imageHash}_${language}`

export const findBy = async (
  imageHash: ImageHash,
  language: ScanLanguage,
): Promise<CachedScan | null> => {
  const doc = await cache().doc(docId(imageHash, language)).get()
  const entry = doc.data()
  if (!entry) return null
  // A scan cached when `ebook` was still a format reads as a book on a screen.
  const { format, ...result } = entry.result
  return { ...entry, result: { ...result, ...heldFormatOf(format) } }
}

export const save = async (entry: CachedScan): Promise<void> => {
  await cache().doc(docId(entry.imageHash, entry.language)).set(withoutAbsentFields(entry))
}

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

export const groundedCallsIn = async (month: string): Promise<number> => {
  const doc = await groundingMonths().doc(month).get()
  return (doc.data()?.calls as number | undefined) ?? 0
}
