import { make } from 'ts-brand'
import { z } from 'zod'
import type { InvitationCode as InvitationCodeType } from '~/domain/friendship/types'

/** The alphabet an invitation code is drawn from: digits and capitals, minus
 *  the four characters nobody can tell apart when reading one out — O and 0, I
 *  and 1. A code is meant to survive being dictated. */
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

/** Eight characters out of thirty-two: a thousand million million codes, so
 *  guessing one is not a way into anybody's library. */
const LENGTH = 8

/** A fresh code. Drawn from the platform's cryptographic generator rather than
 *  `Math.random`: this is the only thing standing between a stranger and a
 *  reader's library. */
export const freshInvitationCode = (): InvitationCodeType => {
  const bytes = crypto.getRandomValues(new Uint8Array(LENGTH))
  const code = Array.from(bytes, (byte) => ALPHABET[byte % ALPHABET.length]).join('')
  return make<InvitationCodeType>()(code)
}

/** A code as it arrives from the app: typed in lower case, pasted with spaces,
 *  or pulled out of the end of an invitation link. Anything that is not a code
 *  answers undefined rather than throwing, so a mistyped one is a message
 *  rather than a crash. */
export const invitationCodeIn = (value: string): InvitationCodeType | undefined => {
  const last =
    value
      .trim()
      .split(/[/\s]+/)
      .filter(Boolean)
      .at(-1) ?? ''
  const cleaned = last.replace(/[^A-Za-z0-9]/g, '').toUpperCase()
  const parsed = z
    .string()
    .regex(new RegExp(`^[${ALPHABET}]{${LENGTH}}$`))
    .safeParse(cleaned)
  return parsed.success ? make<InvitationCodeType>()(parsed.data) : undefined
}

/** The pair, folded into one id so the same friendship is one document whichever
 *  of the two readers asks about it. */
export const friendshipIdOf = (left: string, right: string): string =>
  [left, right].sort().join('--')
