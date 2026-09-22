import type { WriteBatch } from 'firebase-admin/firestore'
import type { Friendship, Invitation, InvitationCode } from '~/domain/friendship/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// Flat, like every other collection. The code IS the document id: an invitation
// is looked up by the only thing the person holding it knows.
const invitations = () =>
  db().collection('friend-invitations').withConverter(genericDataConverter<Invitation>())

// One document per pair, keyed by the two ids sorted, so the friendship is the
// same row whichever of the two reads it.
const friendships = () =>
  db().collection('friendships').withConverter(genericDataConverter<Friendship>())

export const findInvitation = async (code: InvitationCode): Promise<Invitation | null> =>
  (await invitations().doc(code).get()).data() ?? null

export const findInvitationsBy = async (userId: UserId): Promise<Invitation[]> =>
  (await invitations().where('userId', '==', userId).get()).docs.map((doc) => doc.data())

export const saveInvitation = async (invitation: Invitation): Promise<Invitation> => {
  await invitations().doc(invitation.code).set(withoutAbsentFields(invitation))
  return invitation
}

export const removeInvitation = async (code: InvitationCode): Promise<void> => {
  await invitations().doc(code).delete()
}

export const removeInvitations = async (codes: readonly InvitationCode[]): Promise<void> =>
  deleteInBatches(codes.map((code) => invitations().doc(code)))

const friendsCacheKey = (userId: UserId) => `friendships:all:${userId}`

// The friends list, the profile screen's permission check and the account
// deletion all want the same rows in one request. Memoizing the scan means they
// cost one query between them rather than one each.
export const findAllByUser = (userId: UserId): Promise<Friendship[]> =>
  memoizedPerRequest(friendsCacheKey(userId), async () => {
    const snapshot = await friendships().where('userIds', 'array-contains', userId).get()
    return snapshot.docs.map((doc) => doc.data())
  })

export const saveFriendship = async (
  friendship: Friendship,
  batch?: WriteBatch,
): Promise<Friendship> => {
  const ref = friendships().doc(friendship.id)
  const document = withoutAbsentFields(friendship)
  if (batch) batch.set(ref, document)
  else await ref.set(document)
  for (const userId of friendship.userIds) evictFromRequestCache(friendsCacheKey(userId))
  return friendship
}

export const removeFriendship = async (friendship: Friendship): Promise<void> => {
  await friendships().doc(friendship.id).delete()
  for (const userId of friendship.userIds) evictFromRequestCache(friendsCacheKey(userId))
}

/** Everything an account deletion has to take with it: the friendships it was
 *  half of, and the invitation it may have left open. A friendship is deleted
 *  outright rather than left dangling — the other reader loses a friend, which
 *  is what deleting an account means. */
export const removeAllForUser = async (userId: UserId): Promise<void> => {
  const [mine, invited] = await Promise.all([
    findAllByUser(userId),
    invitations().where('userId', '==', userId).get(),
  ])
  await deleteInBatches([
    ...mine.map((friendship) => friendships().doc(friendship.id)),
    ...invited.docs.map((doc) => doc.ref),
  ])
  for (const friendship of mine) {
    for (const member of friendship.userIds) evictFromRequestCache(friendsCacheKey(member))
  }
}
