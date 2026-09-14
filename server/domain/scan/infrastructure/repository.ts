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
  return doc.data() ?? null
}

export const save = async (entry: CachedScan): Promise<void> => {
  await cache().doc(docId(entry.imageHash, entry.language)).set(withoutAbsentFields(entry))
}
