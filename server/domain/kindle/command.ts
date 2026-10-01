import { sealCredentials } from '~/domain/kindle/infrastructure/credentials-vault'
import * as api from '~/domain/kindle/infrastructure/kindle-api'
import * as repository from '~/domain/kindle/infrastructure/repository'
import type {
  ConnectedKindleAccount,
  KindleAsin,
  KindleLogin,
  KindleMarketplace,
} from '~/domain/kindle/types'
import type { UserId } from '~/domain/shared/types'

/** A sign-in the reader walked away from stops being usable after this. The
 *  authorization code Amazon hands back expires within minutes anyway; the
 *  window exists so an abandoned attempt cannot be completed days later. */
const PENDING_LOGIN_TTL_MS = 30 * 60 * 1000

export namespace KindleCommand {
  /** Open a sign-in. The exchange is PKCE, so the verifier is written down here
   *  and the app only ever sees the page to show.
   *
   *  A connection already in place is left alone until the new one completes: a
   *  reader who opens the sheet and changes their mind must not come back to a
   *  disconnected library. */
  export const startLogin = async (
    userId: UserId,
    marketplace: KindleMarketplace,
    now = new Date(),
  ): Promise<KindleLogin> => {
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
    return { url: loginUrl, cookies, redirectUrl: api.landingUrlFor(marketplace) }
  }

  /** Trade the authorization code the web view caught for device credentials,
   *  and keep them sealed. The spent sign-in is dropped in the same write: a
   *  code verifier is good for one exchange. */
  export const completeLogin = async (
    userId: UserId,
    authorizationCode: string,
    now = new Date(),
  ): Promise<ConnectedKindleAccount | 'no-pending-login' | 'login-expired'> => {
    const connection = await repository.findByUser(userId)
    const pending = connection?.pending
    if (!pending) return 'no-pending-login'
    if (now.getTime() - pending.startedAt.getTime() > PENDING_LOGIN_TTL_MS) {
      await repository.save({ userId, account: connection?.account })
      return 'login-expired'
    }

    // Named after the app, so the reader can tell it apart in Amazon's device
    // list and remove it there.
    const credentials = await api.register(
      authorizationCode,
      {
        codeVerifier: pending.codeVerifier,
        serial: pending.serial,
        locale: pending.marketplace,
        createdAt: pending.startedAt,
      },
      { deviceName: 'Shiori' },
    )

    const account: ConnectedKindleAccount = {
      marketplace: pending.marketplace,
      credentials: sealCredentials(credentials),
      connectedAt: now,
      // A reader who links their library is asking for it to follow them.
      // Written rather than left absent, so the switch the app draws is the
      // setting that is stored.
      autoSync: true,
    }
    await repository.save({ userId, account })
    return account
  }

  /** Note a pass that went through: when, and — when given — which titles Amazon
   *  reported read, the set the next pass reads news against. Without one the
   *  stored set is left as it is. Clears a failure a night before recorded. */
  export const recordPass = async (
    userId: UserId,
    readAsins: readonly KindleAsin[] | undefined,
    now = new Date(),
  ): Promise<void> =>
    patchAccount(userId, {
      lastImportedAt: now,
      ...(readAsins ? { readAsins: [...readAsins] } : {}),
      lastSyncFailedAt: undefined,
    })

  /** Note a nightly pass that failed, for the app to offer a reconnection. */
  export const recordFailure = async (userId: UserId, now = new Date()): Promise<void> =>
    patchAccount(userId, { lastSyncFailedAt: now })

  /** Turn the nightly sync on or off. `not-connected` rather than a setting
   *  written onto nothing: without an account there is no library to sync. */
  export const setAutoSync = async (
    userId: UserId,
    enabled: boolean,
  ): Promise<ConnectedKindleAccount | 'not-connected'> => {
    const connection = await repository.findByUser(userId)
    if (!connection?.account) return 'not-connected'
    const account: ConnectedKindleAccount = { ...connection.account, autoSync: enabled }
    await repository.save({ ...connection, account })
    return account
  }

  /** Forget the connection. Only our copy of the credentials goes: the device
   *  stays registered on the Amazon side until the reader removes it there. */
  export const disconnect = async (userId: UserId): Promise<'disconnected' | 'not-connected'> => {
    const connection = await repository.findByUser(userId)
    if (!connection) return 'not-connected'
    await repository.remove(userId)
    return 'disconnected'
  }

  /** Erase the reader's connection outright — an account deletion takes it. */
  export const deleteForUser = async (userId: UserId): Promise<void> => repository.remove(userId)
}

/** Change fields of the stored account, on whatever is stored right now.
 *  Re-read rather than patched onto the caller's copy, which may predate a write
 *  made during the same pass. */
const patchAccount = async (
  userId: UserId,
  patch: Partial<ConnectedKindleAccount>,
): Promise<void> => {
  const connection = await repository.findByUser(userId)
  if (!connection?.account) return
  await repository.save({ ...connection, account: { ...connection.account, ...patch } })
}
