import type { DocumentData, Firestore, QueryDocumentSnapshot } from 'firebase-admin/firestore'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'
import { eachWithAtMostInFlight } from '~/utils/concurrency'

type Doc = DocumentData

/** How many documents move side by side: each is a transaction of its own. */
const MOVES_IN_FLIGHT = 20

/** A collection whose ids are made of several parts, with the fields that
 *  name them, and how a document stored under both ids keeps what each holds. */
type Rekeyed = {
  collection: string
  parts: readonly string[]
  merge: (current: Doc, legacy: Doc) => Doc
}

/** The document written under its current id since the deploy was built from
 *  the legacy one, which the code read when the current one held nothing: it
 *  is the later of the two. */
const keepCurrent = (current: Doc) => current

const REKEYED: readonly Rekeyed[] = [
  // A scan may have been counted under either id while two revisions served
  // side by side: the higher count is the one nobody can have spent past.
  {
    collection: 'ai-quotas',
    parts: ['userId', 'month'],
    merge: (current, legacy) => ({
      ...current,
      scans: Math.max(Number(current.scans ?? 0), Number(legacy.scans ?? 0)),
    }),
  },
  { collection: 'scan-cache', parts: ['imageHash', 'language'], merge: keepCurrent },
  { collection: 'series-opinions', parts: ['userId', 'seriesId'], merge: keepCurrent },
  { collection: 'author-favorites', parts: ['userId', 'authorKey'], merge: keepCurrent },
  { collection: 'narrator-favorites', parts: ['userId', 'narratorKey'], merge: keepCurrent },
]

/** The id `compositeId` gives the document now, from the fields it holds;
 *  undefined when one is missing, and the document is left where it is. */
const currentIdOf = (data: Doc, parts: readonly string[]) => {
  const values = parts.map((part) => data[part])
  return values.every((value) => typeof value === 'string' && value.length > 0)
    ? values.join('~')
    : undefined
}

/** Move one document to its current id, in a transaction: a reader writing it
 *  meanwhile is neither lost nor overwritten. Answers whether it moved. */
const moved = (
  db: Firestore,
  { collection, merge }: Rekeyed,
  legacy: QueryDocumentSnapshot,
  currentId: string,
): Promise<boolean> =>
  db.runTransaction(async (tx) => {
    const target = db.collection(collection).doc(currentId)
    const [still, current] = [await tx.get(legacy.ref), await tx.get(target)]
    const legacyData = still.data()
    if (!legacyData) return false
    const currentData = current.data()
    tx.set(target, currentData ? merge(currentData, legacyData) : legacyData)
    tx.delete(legacy.ref)
    return true
  })

/** Every composite document id built with `~`.
 *
 *  Ids made of several parts were joined three ways: `~` (sync removals,
 *  dismissals, projections, catalogues), `--` (series opinions, author and
 *  narrator hearts) and `_` (monthly quotas, the scan cache). They now all take
 *  `~`, which no part can hold. Each document is copied under its new id and
 *  the old one removed; one already under its new id is left alone, so the
 *  migration runs again harmlessly.
 *
 *  The code deployed with it reads the legacy id where the new one holds
 *  nothing, until this has run: no quota reads as fresh, no opinion or heart
 *  vanishes, no cached scan is paid for again.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const idsTakeOneSeparator: Migration = {
  version: MigrationVersion(37),
  name: MigrationName('ids-take-one-separator'),
  migrate: async ({ db }) => {
    let transformed = 0
    for (const rekeyed of REKEYED) {
      const { docs } = await db.collection(rekeyed.collection).get()
      const moves = docs.flatMap((doc) => {
        const currentId = currentIdOf(doc.data(), rekeyed.parts)
        return currentId && currentId !== doc.ref.id ? [{ doc, currentId }] : []
      })
      await eachWithAtMostInFlight(moves, MOVES_IN_FLIGHT, async ({ doc, currentId }) => {
        if (await moved(db, rekeyed, doc, currentId)) transformed += 1
      })
    }
    return { ok: true, transformed }
  },
}
