import type { KeptDescription, Release } from '~/domain/release/types'
import type { Language } from '~/domain/shared/language'
import { db } from '~/system/firebase'
import { evictFromRequestCache } from '~/system/request-cache'
import {
  findDocumentsPerRequest,
  genericDataConverter,
  withoutAbsentFields,
} from '~/utils/firestore'

// Shared, holding no reference to any reader: keyed by the book, the format
// and the language of the edition. The edition watch and the page's
// description of one release live in its one document, so a list and the page
// it opens read the same thing.
const releases = () => db().collection('releases').withConverter(genericDataConverter<Release>())

const cacheKeyOf = (key: string) => `releases:${key}`

/** The releases under these keys, each read once per request whoever asks it:
 *  the awaited editions, the awards and the discoveries composed in one
 *  request read the same documents. */
export const findReleases = (keys: readonly string[]): Promise<Release[]> =>
  findDocumentsPerRequest(releases(), keys, cacheKeyOf)

/** What the web was found to say of an edition, written over what the last
 *  look said and beside its descriptions, which stay: one transaction, so a
 *  description kept meanwhile is never lost. */
export const saveWatch = async (watch: Omit<Release, 'descriptions'>): Promise<void> => {
  const ref = releases().doc(watch.key)
  await db().runTransaction(async (tx) => {
    const existing = (await tx.get(ref)).data() as Release | undefined
    const descriptions = existing?.descriptions
    tx.set(ref, withoutAbsentFields({ ...watch, ...(descriptions ? { descriptions } : {}) }))
  })
  evictFromRequestCache(cacheKeyOf(watch.key))
}

/** A description in one language of the app, kept beside whatever the
 *  release holds — its watch, its descriptions in other languages. The
 *  release is created with the book it is of when it held nothing yet. */
export const saveDescription = async (
  identity: Omit<Release, 'descriptions' | 'checkedAt' | 'found'>,
  language: Language,
  kept: KeptDescription,
): Promise<Release> => {
  const ref = releases().doc(identity.key)
  const saved = await db().runTransaction(async (tx) => {
    const existing = (await tx.get(ref)).data() as Release | undefined
    const release: Release = {
      ...identity,
      ...existing,
      descriptions: { ...existing?.descriptions, [language]: kept },
    }
    tx.set(ref, withoutAbsentFields(release))
    return release
  })
  evictFromRequestCache(cacheKeyOf(identity.key))
  return saved
}
