import { chunk } from 'lodash-es'
import { Subgenre } from '~/domain/book/primitives'
import type { LocalizedSubgenre, Subgenre as SubgenreValue } from '~/domain/book/types'
import { SubgenreQuery } from '~/domain/subgenre/query'
import { SubgenreUseCase } from '~/domain/subgenre/use-case'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'
import { optionally as optional } from '~/utils/input'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400
// Labels per model call: enough that a whole library is a handful of calls,
// few enough that one answer stays short and lines up with its question.
const TRANSLATION_CHUNK = 60

/** Turns every stored subgenre — a bare label in whichever language the scan,
 *  the import or the reader wrote it — into its French and English pair, so a
 *  record reads in the app's language.
 *
 *  Every distinct label of the database is translated once, not once per book,
 *  and filed in the shared dictionary on the way. A label the dictionary
 *  already knows, from either side, costs nothing. A failed call fails the
 *  migration before any book is rewritten, so running it again starts clean.
 *
 *  Reads the raw documents rather than going through the book repository: a
 *  migration must not depend on a domain type that may change after it. */
export const localizeSubgenres: Migration = {
  version: MigrationVersion(3),
  name: MigrationName('localize-subgenres'),
  migrate: async ({ db }) => {
    const snapshot = await db.collection('books').get()
    const stored = snapshot.docs.flatMap((doc) => {
      const subgenres: unknown = doc.data().subgenres
      if (!Array.isArray(subgenres)) return []
      const labels = subgenres.filter((label): label is string => typeof label === 'string')
      return labels.length > 0 ? [{ doc, subgenres, labels }] : []
    })

    const distinct = [
      ...new Map(
        stored
          .flatMap(({ labels }) => labels)
          .map((label) => optional(label, Subgenre))
          .filter((label): label is SubgenreValue => label !== undefined)
          .map((label) => [label.toLocaleLowerCase(), label]),
      ).values(),
    ]
    const pairs = new Map<string, LocalizedSubgenre>()
    for (const labels of chunk(distinct, TRANSLATION_CHUNK)) {
      const known = await Promise.all([
        SubgenreQuery.known(labels, 'fr'),
        SubgenreQuery.known(labels, 'en'),
      ])
      const unknown = labels.filter(
        (label) =>
          !known.some((found) => [...found.values()].some((pair) => isPairOf(pair, label))),
      )
      for (const found of known) for (const pair of found.values()) remember(pairs, pair)
      // Aligned with the question, so a label the model respelled on both
      // sides still finds its pair.
      const translated = await SubgenreUseCase.translateUnknown(unknown)
      unknown.forEach((label, index) => {
        remember(pairs, translated[index])
        pairs.set(label.toLocaleLowerCase(), translated[index])
      })
    }

    const rewritten = stored.map(({ doc, subgenres }) => ({
      ref: doc.ref,
      subgenres: subgenres.flatMap((entry: unknown) => {
        if (typeof entry !== 'string') return [entry]
        const label = optional(entry, Subgenre)
        const pair = label && pairs.get(label.toLocaleLowerCase())
        return pair ? [pair] : []
      }),
    }))
    for (const slice of chunk(rewritten, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, subgenres } of slice) batch.update(ref, { subgenres })
      await batch.commit()
    }
    return { ok: true, transformed: rewritten.length }
  },
}

const isPairOf = (pair: LocalizedSubgenre, label: SubgenreValue) =>
  Object.values(pair).some((side) => side.toLocaleLowerCase() === label.toLocaleLowerCase())

/** Files a pair under each of its sides, so a label finds it whichever
 *  language it was written in. */
const remember = (pairs: Map<string, LocalizedSubgenre>, pair: LocalizedSubgenre) => {
  for (const side of Object.values(pair)) pairs.set(side.toLocaleLowerCase(), pair)
}
