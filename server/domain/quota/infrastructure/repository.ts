import { freshQuota, noCredit } from '~/domain/quota/business-rules'
import type { Quota, QuotaMonth, ScanCredit, ScanDebit } from '~/domain/quota/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import {
  compositeId,
  deleteAllOwnedBy,
  genericDataConverter,
  transactionally,
  withoutAbsentFields,
} from '~/utils/firestore'

const quotas = () => db().collection('ai-quotas').withConverter(genericDataConverter<Quota>())

const credits = () =>
  db().collection('ai-credits').withConverter(genericDataConverter<ScanCredit>())

// One document per account and per month, keyed deterministically: the month's
// quota is read by key, never by query, and last month's document is simply never
// read again — no purge, no scheduled job.
const quotaDocId = (userId: UserId, month: QuotaMonth) => compositeId(userId, month)

const cacheKey = (userId: UserId, month: QuotaMonth) => `quota:${userId}:${month}`

// One document per account, whose id IS the userId: a balance has no period, so
// there is nothing else to key it on.
const creditCacheKey = (userId: UserId) => `quota:credit:${userId}`

// Memoized for the request: the scan checks the quota before calling Gemini and
// records it after, and both must share the same single read.
export const findBy = (userId: UserId, month: QuotaMonth): Promise<Quota> =>
  memoizedPerRequest(cacheKey(userId, month), async () => {
    const doc = await quotas().doc(quotaDocId(userId, month)).get()
    // An absent document is a month nobody has spent anything in — the storage
    // boundary defaults it rather than making every caller handle absence.
    return doc.data() ?? freshQuota(userId, month)
  })

// Spend one scan, choosing the counter and spending it in one transaction: both documents are
// read inside it, so two scans landing together at the month's last scan cannot both take it
// from the month — the second sees it gone and draws on the granted balance, or on nothing.
// `debitOf` picks the counter; `spendMonth` / `spendCredit` say what each becomes.
export const spendOne = async (
  userId: UserId,
  month: QuotaMonth,
  debitOf: (quota: Quota, credit: ScanCredit) => ScanDebit,
  spendMonth: (quota: Quota) => Quota,
  spendCredit: (credit: ScanCredit) => ScanCredit,
): Promise<ScanDebit> => {
  const quotaRef = quotas().doc(quotaDocId(userId, month))
  const creditRef = credits().doc(userId)
  const debit = await transactionally(async (tx) => {
    const [quotaDoc, creditDoc] = await Promise.all([tx.get(quotaRef), tx.get(creditRef)])
    const quota = quotaDoc.data() ?? freshQuota(userId, month)
    const credit = creditDoc.data() ?? noCredit(userId)
    const debit = debitOf(quota, credit)
    if (debit.on === 'monthly') tx.set(quotaRef, withoutAbsentFields(spendMonth(quota)))
    if (debit.on === 'credit') tx.set(creditRef, withoutAbsentFields(spendCredit(credit)))
    return debit
  })
  evictFromRequestCache(cacheKey(userId, month))
  evictFromRequestCache(creditCacheKey(userId))
  return debit
}

// The scans the account was granted. Memoized for the same reason as the month's
// quota: the scan gate reads the balance before calling Gemini and the resolver
// reads it again to display it, on one read.
export const findCredit = (userId: UserId): Promise<ScanCredit> =>
  memoizedPerRequest(creditCacheKey(userId), async () => {
    const doc = await credits().doc(userId).get()
    return doc.data() ?? noCredit(userId)
  })

// Add to the balance, atomically and at most once: `topUp` answers nothing when
// the grant was handed already, and nothing is written then. The read is inside
// the transaction because the app syncs its subscription on every launch, and
// two launches racing must not both see the grant missing.
export const topUpCredit = async (
  userId: UserId,
  topUp: (credit: ScanCredit) => ScanCredit | undefined,
): Promise<ScanCredit> => {
  const ref = credits().doc(userId)
  const credit = await transactionally(async (tx) => {
    const doc = await tx.get(ref)
    const held = doc.data() ?? noCredit(userId)
    const toppedUp = topUp(held)
    if (!toppedUp) return held
    tx.set(ref, withoutAbsentFields(toppedUp))
    return toppedUp
  })
  evictFromRequestCache(creditCacheKey(userId))
  return credit
}

// Delete every monthly quota document the account has accrued, and its granted
// balance (account deletion). One doc per month, so the quotas are queried by
// userId rather than reconstructing keys; the balance is a single known key.
export const removeAllByUser = async (userId: UserId): Promise<void> => {
  await deleteAllOwnedBy(quotas(), userId, [credits().doc(userId)])
  evictFromRequestCache(creditCacheKey(userId))
}
