import type { LocalizedSubgenre } from '~/domain/book/types'
import { translationKeysOf } from '~/domain/subgenre/business-rules'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'

// A single global collection, like the series catalogue: a translation is a fact
// about words with no reference to any reader, so the model call that produced
// it is paid once for everybody. Each entry is stored under one key per
// language, so a label is found from whichever side it was typed on.
const translations = () =>
  db().collection('subgenre-translations').withConverter(genericDataConverter<LocalizedSubgenre>())

// One getAll for every label of a write rather than a lookup per label.
export const findByKeys = async (
  keys: readonly string[],
): Promise<Map<string, LocalizedSubgenre>> => {
  if (keys.length === 0) return new Map()
  const snapshots = await db().getAll(...keys.map((key) => translations().doc(key)))
  return new Map(
    snapshots.flatMap((snapshot) => {
      const data = snapshot.data() as LocalizedSubgenre | undefined
      return data ? [[snapshot.id, data] as const] : []
    }),
  )
}

export const save = async (subgenres: readonly LocalizedSubgenre[]): Promise<void> => {
  if (subgenres.length === 0) return
  const batch = db().batch()
  for (const subgenre of subgenres)
    for (const key of translationKeysOf(subgenre))
      batch.set(translations().doc(key), { ...subgenre })
  await batch.commit()
}
