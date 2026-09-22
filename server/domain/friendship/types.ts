import type { Brand } from 'ts-brand'
import type { SharedShelf } from '~/domain/analytics/types'
import type { UserId } from '~/domain/shared/types'

/** The code that turns an invitation into a friendship. Short enough to read
 *  aloud down a phone, random enough that nobody guesses their way into
 *  somebody's library. */
export type InvitationCode = Brand<string, 'InvitationCode'>

/** An invitation one reader made, waiting for another to take it.
 *
 *  One live invitation per reader, reused until it expires: a reader who taps
 *  "invite" three times has shared one link three times, not left three keys to
 *  their library lying around. */
export type Invitation = {
  code: InvitationCode
  userId: UserId
  createdAt: Date
  expiresAt: Date
}

/** Two readers who share their libraries.
 *
 *  One document for the pair, not one per reader: friendship here is symmetric
 *  — accepting opens both libraries at once — and storing it twice would be
 *  storing one fact in two places that can disagree. The pair is folded into
 *  the document id, sorted, so it is the same id whichever of the two asks. */
export type Friendship = {
  id: string
  userIds: UserId[]
  since: Date
}

/** A friend as the list shows them: who they are and since when. Their library
 *  is a separate read — a list of six friends must not fetch six libraries. */
export type Friend = {
  userId: UserId
  firstName?: string
  since: Date
  /** Their shelf in figures, without the books they keep to themselves. Read
   *  from their dashboard view, one document per friend, never their books. */
  shelf?: SharedShelf
}
