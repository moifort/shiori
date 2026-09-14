import type { WriteBatch } from 'firebase-admin/firestore'
import type { UserId } from '~/domain/shared/types'
import type { UserProfile } from '~/domain/user/types'
import { db } from '~/system/firebase'
import { deleteAuthUser } from '~/system/identity'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter } from '~/utils/firestore'

const profiles = () =>
  db().collection('user-profiles').withConverter(genericDataConverter<UserProfile>())

const cacheKey = (userId: UserId) => `user:profile:${userId}`

// A user's profile — at most one, since the doc id IS the userId. Memoized: the
// auth gate reads it on every launch, so it must cost a single read per request.
export const findProfile = (userId: UserId): Promise<UserProfile | null> =>
  memoizedPerRequest(cacheKey(userId), async () => {
    const doc = await profiles().doc(userId).get()
    return doc.data() ?? null
  })

// How many accounts have a profile — a Firestore count() aggregate, one billed
// query round-trip however large the collection grows, never a scan.
export const countProfiles = async (): Promise<number> => {
  const snap = await profiles().count().get()
  return snap.data().count
}

export const saveProfile = async (
  profile: UserProfile,
  batch?: WriteBatch,
): Promise<UserProfile> => {
  const ref = profiles().doc(profile.userId)
  if (batch) batch.set(ref, profile)
  else await ref.set(profile)
  // Drop the memoized pre-write value: the onboarding reads the profile to know
  // whether it is the first one, then answers with what it just wrote, and the
  // absence it saw on the way in must not be what the caller reads back.
  evictFromRequestCache(cacheKey(profile.userId))
  return profile
}

// Delete the account's profile (account deletion). Idempotent: an already-absent
// profile is a no-op, so a retried deletion never errors.
export const removeProfile = async (userId: UserId): Promise<void> => {
  await profiles().doc(userId).delete()
  evictFromRequestCache(cacheKey(userId))
}

// Delete the account's auth identity (account deletion). The one place the auth
// provider is touched, keeping external access inside the storage layer.
export const removeAuthUser = async (userId: UserId): Promise<void> => {
  await deleteAuthUser(userId)
}
