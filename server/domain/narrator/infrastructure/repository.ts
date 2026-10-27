import type { Narrator, NarratorKey } from '~/domain/narrator/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// A single global collection, as `authors` is: a narrator's face is a fact
// about the world with no reference to any reader, so one document serves
// everyone. It is never exposed through library sharing.
const narrators = () => db().collection('narrators').withConverter(genericDataConverter<Narrator>())

const cacheKey = (key: NarratorKey) => `narrators:${key}`

export const findByKey = (key: NarratorKey): Promise<Narrator | null> =>
  memoizedPerRequest(cacheKey(key), async () => {
    const doc = await narrators().doc(key).get()
    return doc.data() ?? null
  })

export const save = async (entry: Narrator): Promise<Narrator> => {
  await narrators().doc(entry.key).set(withoutAbsentFields(entry))
  evictFromRequestCache(cacheKey(entry.key))
  return entry
}
