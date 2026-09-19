import type { AudibleCredentials } from 'audible-api-ts'
import * as api from '~/domain/audible/infrastructure/audible-api'
import { sealCredentials } from '~/domain/audible/infrastructure/credentials-vault'
import * as repository from '~/domain/audible/infrastructure/repository'
import type { AudibleLogin, AudibleMarketplace, ConnectedAccount } from '~/domain/audible/types'
import type { UserId } from '~/domain/shared/types'

/** A sign-in the reader walked away from stops being usable after this. The
 *  authorization code Amazon hands back expires within minutes anyway; the
 *  window exists so an abandoned attempt cannot be completed days later by
 *  whoever gets hold of the code. */
const PENDING_LOGIN_TTL_MS = 30 * 60 * 1000

export namespace AudibleCommand {
  /** Open a sign-in. The exchange is PKCE, so the verifier is written down here
   *  and the app only ever sees the page to show.
   *
   *  A connection already in place is left alone until the new one completes: a
   *  reader who opens the sheet and changes their mind must not come back to a
   *  disconnected account. */
  export const startLogin = async (
    userId: UserId,
    marketplace: AudibleMarketplace,
    now = new Date(),
  ): Promise<AudibleLogin> => {
    const { loginUrl, session, cookies } = await api.login(marketplace)
    const existing = await repository.findByUser(userId)
    await repository.save({
      userId,
      account: existing?.account,
      pending: {
        marketplace,
        codeVerifier: session.codeVerifier,
        serial: session.serial,
        startedAt: now,
      },
    })
    return { url: loginUrl, cookies, redirectUrl: api.landingUrlOf(marketplace) }
  }

  /** Trade the authorization code the web view caught for device credentials,
   *  and keep them sealed.
   *
   *  The spent sign-in is dropped in the same write, whatever the outcome of the
   *  registration would have been: a code verifier is good for one exchange. */
  export const completeLogin = async (
    userId: UserId,
    authorizationCode: string,
    now = new Date(),
  ): Promise<ConnectedAccount | 'no-pending-login' | 'login-expired'> => {
    const connection = await repository.findByUser(userId)
    const pending = connection?.pending
    if (!pending) return 'no-pending-login'
    if (now.getTime() - pending.startedAt.getTime() > PENDING_LOGIN_TTL_MS) {
      await repository.save({ userId, account: connection?.account })
      return 'login-expired'
    }

    const credentials = await api.register(authorizationCode, {
      codeVerifier: pending.codeVerifier,
      serial: pending.serial,
      locale: pending.marketplace,
      createdAt: pending.startedAt,
    })

    const account: ConnectedAccount = {
      marketplace: pending.marketplace,
      credentials: sealCredentials(credentials),
      connectedAt: now,
    }
    await repository.save({ userId, account })
    return account
  }

  /** Write back the credentials the Audible client rotated. The access token has
   *  a short life and the client refreshes it on its own; not storing what came
   *  back means paying for that refresh on every single call. */
  export const rememberRotatedCredentials = async (
    userId: UserId,
    credentials: AudibleCredentials,
  ): Promise<void> => patchAccount(userId, { credentials: sealCredentials(credentials) })

  export const recordImport = async (userId: UserId, now = new Date()): Promise<void> =>
    patchAccount(userId, { lastImportedAt: now })

  /** Forget the connection. Only our copy of the credentials goes: the device
   *  stays registered on the Amazon side until the reader removes it there, which
   *  the app says. */
  export const disconnect = async (userId: UserId): Promise<'disconnected' | 'not-connected'> => {
    const connection = await repository.findByUser(userId)
    if (!connection) return 'not-connected'
    await repository.remove(userId)
    return 'disconnected'
  }

  /** Erase the reader's connection outright — an account deletion takes it. */
  export const deleteForUser = async (userId: UserId): Promise<void> => repository.remove(userId)
}

/** Change one field of the stored account, on whatever is stored right now.
 *
 *  Re-read rather than patched onto the caller's copy: an import rotates the
 *  access token and then notes the date, and writing the second from a snapshot
 *  taken before the first would put the spent token straight back. */
const patchAccount = async (userId: UserId, patch: Partial<ConnectedAccount>): Promise<void> => {
  const connection = await repository.findByUser(userId)
  if (!connection?.account) return
  await repository.save({ ...connection, account: { ...connection.account, ...patch } })
}
