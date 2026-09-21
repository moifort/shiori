import * as repository from '~/domain/friendship/infrastructure/repository'
import {
  freshInvitationCode,
  friendshipIdOf,
  invitationCodeIn,
} from '~/domain/friendship/primitives'
import type { Friendship, Invitation } from '~/domain/friendship/types'
import type { UserId } from '~/domain/shared/types'

/** How long an invitation stands. Long enough to be sent and picked up a few
 *  days later, short enough that a link forwarded around a group chat a month
 *  on no longer opens anybody's library. */
const INVITATION_DAYS = 7

const DAY_MS = 86_400_000

export namespace FriendshipCommand {
  /** The reader's invitation: the one still standing, or a fresh one.
   *
   *  Reused rather than piled up. A reader who taps "invite" three times has
   *  shared one link three times, and every extra code would be another key to
   *  their library outstanding. */
  export const invite = async (userId: UserId, now = new Date()): Promise<Invitation> => {
    const live = await repository.findLiveInvitationBy(userId, now)
    if (live) return live
    return repository.saveInvitation({
      code: freshInvitationCode(),
      userId,
      createdAt: now,
      expiresAt: new Date(now.getTime() + INVITATION_DAYS * DAY_MS),
    })
  }

  /** Take an invitation up.
   *
   *  The code is spent on success: it opened the library it was meant to open,
   *  and leaving it live would let whoever else the link reached in too. An
   *  expired one is cleaned up on the way past rather than left to rot.
   *
   *  Accepting twice is not an error — two readers tapping the same link at
   *  once, a retry after a dropped connection — it answers the friendship that
   *  already exists. */
  export const accept = async (
    userId: UserId,
    code: string,
    now = new Date(),
  ): Promise<Friendship | 'not-found' | 'expired' | 'own-invitation'> => {
    // Whatever the app hands over: the code, the link that ends with it, typed
    // in lower case or pasted with a stray space around it.
    const parsed = invitationCodeIn(code)
    if (!parsed) return 'not-found'
    const invitation = await repository.findInvitation(parsed)
    if (!invitation) return 'not-found'
    if (invitation.expiresAt <= now) {
      await repository.removeInvitation(parsed)
      return 'expired'
    }
    if (invitation.userId === userId) return 'own-invitation'

    const friendship: Friendship = {
      id: friendshipIdOf(invitation.userId, userId),
      userIds: [invitation.userId, userId].sort() as UserId[],
      since: now,
    }
    const existing = (await repository.findAllByUser(userId)).find(
      (entry) => entry.id === friendship.id,
    )
    if (existing) {
      await repository.removeInvitation(parsed)
      return existing
    }
    await repository.saveFriendship(friendship)
    await repository.removeInvitation(parsed)
    return friendship
  }

  /** Either of the two can end it, and it ends for both: one document, one
   *  fact, and a reader who no longer wants to be read must not have to ask the
   *  other to agree. */
  export const remove = async (
    userId: UserId,
    friendId: UserId,
  ): Promise<'removed' | 'not-found'> => {
    const id = friendshipIdOf(userId, friendId)
    const friendship = (await repository.findAllByUser(userId)).find((entry) => entry.id === id)
    if (!friendship) return 'not-found'
    await repository.removeFriendship(friendship)
    return 'removed'
  }

  /** An account deletion takes its friendships with it, and the invitation it
   *  may have left open. */
  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllForUser(userId)
}
