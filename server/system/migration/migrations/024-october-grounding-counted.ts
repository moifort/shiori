import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

/** The grounded calls October had made before the month was counted, read
 *  from the bill: 9,121 Google searches up to 2026-10-20 — the 5,002 free and
 *  4,119 paid — at 6.3 searches a call.
 *
 *  The counter that moves grounded steps to Claude once Gemini's free searches
 *  are spent began on 2026-10-20 at nought, three weeks into a month whose
 *  free searches were long gone: it would have kept every grounded step on
 *  Gemini, billed, for some 700 more calls. A count already past this one is
 *  kept.
 *
 *  Reads the raw document rather than going through the repository: a
 *  migration must not depend on a domain type that may change after it. */
const OCTOBER_CALLS_BEFORE_COUNTING = 1448

export const octoberGroundingCounted: Migration = {
  version: MigrationVersion(24),
  name: MigrationName('october-grounding-counted'),
  migrate: async ({ db }) => {
    const ref = db.collection('grounding-months').doc('2026-10')
    const counted = ((await ref.get()).data()?.calls as number | undefined) ?? 0
    if (counted >= OCTOBER_CALLS_BEFORE_COUNTING) return { ok: true, transformed: 0 }
    await ref.set(
      { month: '2026-10', calls: OCTOBER_CALLS_BEFORE_COUNTING + counted },
      { merge: true },
    )
    return { ok: true, transformed: 1 }
  },
}
