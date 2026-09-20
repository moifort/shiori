import { FieldValue } from 'firebase-admin/firestore'
import { freshUsage } from '~/domain/admin/business-rules'
import type { AdminMetricsProjection, AiUsage } from '~/domain/admin/types'
import type { Month } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

const usages = () => db().collection('ai-usage').withConverter(genericDataConverter<AiUsage>())

const projections = () =>
  db().collection('admin-metrics').withConverter(genericDataConverter<AdminMetricsProjection>())

// The single read-model document the daily refresh overwrites. There is one set
// of metrics for the whole app, so it has nothing to be keyed on.
const PROJECTION_DOC = 'current'

/** What one step of one scan consumed, before it is a counter — plain numbers,
 *  the currency the Gemini client answers in. */
type StepDelta = {
  promptTokens: number
  outputTokens: number
  thinkingTokens: number
  searches: number
}

// Fold one scan into the month's counters, atomically and without a read: a
// merge of increments is one write whatever lands concurrently, and it creates
// the month's document on its first scan. Written through a raw reference — the
// increment sentinels are not an AiUsage, so the typed converter cannot carry them.
export const recordUsage = async (
  month: Month,
  delta: {
    scans: number
    cacheHits: number
    vision?: StepDelta
    enrichment?: StepDelta
    catalogue?: StepDelta
  },
): Promise<void> => {
  await db()
    .collection('ai-usage')
    .doc(month)
    .set(
      {
        month,
        scans: FieldValue.increment(delta.scans),
        cacheHits: FieldValue.increment(delta.cacheHits),
        vision: stepIncrements(delta.vision),
        enrichment: stepIncrements(delta.enrichment),
        catalogue: stepIncrements(delta.catalogue),
      },
      { merge: true },
    )
}

// A step that never ran increments by zero rather than being left out: the
// month's document then always carries all three, so a reader never has to tell
// an absent step from a free one.
const stepIncrements = (step: StepDelta | undefined) => ({
  promptTokens: FieldValue.increment(step?.promptTokens ?? 0),
  outputTokens: FieldValue.increment(step?.outputTokens ?? 0),
  thinkingTokens: FieldValue.increment(step?.thinkingTokens ?? 0),
  searches: FieldValue.increment(step?.searches ?? 0),
})

// An absent document is a month nobody has scanned in — the storage boundary
// defaults it, mirroring the quota repository.
export const findUsage = async (month: Month): Promise<AiUsage> => {
  const doc = await usages().doc(month).get()
  return doc.data() ?? freshUsage(month)
}

export const findProjection = async (): Promise<AdminMetricsProjection | undefined> => {
  const doc = await projections().doc(PROJECTION_DOC).get()
  return doc.data()
}

export const saveProjection = async (
  projection: AdminMetricsProjection,
): Promise<AdminMetricsProjection> => {
  // Full set: the refresh recomputes everything, and an optional section that
  // came back absent (revenue, infra) must disappear rather than linger.
  await projections().doc(PROJECTION_DOC).set(withoutAbsentFields(projection))
  return projection
}
