import { heldFormatOf } from '~/domain/scan/business-rules'
import type { CachedScan, ImageHash, ScanLanguage } from '~/domain/scan/types'
import { db } from '~/system/firebase'
import { compositeId, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// A global collection, like the series catalogue and for the same reason: a
// scanned cover is a fact about an image, not about whoever photographed it, so
// one entry serves every reader who scans the same edition. It holds no user id.
const cache = () => db().collection('scan-cache').withConverter(genericDataConverter<CachedScan>())

// Keyed by image AND language: the same cover scanned in two languages must not
// serve one language's synopsis to the other.
const docId = (imageHash: ImageHash, language: ScanLanguage) => compositeId(imageHash, language)

// The id an entry had before ids took one separator, read when the current one
// holds nothing: migration 037 moves the entries, and this covers the minutes
// between a deploy and its migration, where a miss is a paid Gemini scan.
// Remove it, and the fallback read, once 037 has run in production.
const legacyDocId = (imageHash: ImageHash, language: ScanLanguage) => `${imageHash}_${language}`

export const findBy = async (
  imageHash: ImageHash,
  language: ScanLanguage,
): Promise<CachedScan | undefined> => {
  const entry =
    (await cache().doc(docId(imageHash, language)).get()).data() ??
    (await cache().doc(legacyDocId(imageHash, language)).get()).data()
  if (!entry) return undefined
  // A scan cached when `ebook` was still a format reads as a book on a screen.
  const { format, ...result } = entry.result
  return { ...entry, result: { ...result, ...heldFormatOf(format) } }
}

export const save = async (entry: CachedScan): Promise<void> => {
  await cache().doc(docId(entry.imageHash, entry.language)).set(withoutAbsentFields(entry))
}
