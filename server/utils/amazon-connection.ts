import type { createLogger } from '~/system/logger'

/** An Amazon connection — Audible's or the Kindle's — with its credentials
 *  opened, or `not-connected`.
 *
 *  Credentials sealed with a key that no longer exists cannot be opened again,
 *  and never will be. That is a connection in name only, so it is dropped here
 *  rather than reported as an Amazon failure the reader could retry forever:
 *  the app then offers to connect again, which is the one thing that works. */
export const openedConnection = async <
  Reader,
  Account extends { credentials: Sealed },
  Sealed,
  Credentials,
>(
  reader: Reader,
  {
    accountOf,
    openIfReadable,
    disconnect,
    logger,
  }: {
    accountOf: (reader: Reader) => Promise<Account | undefined>
    openIfReadable: (sealed: Sealed) => Credentials | undefined
    disconnect: (reader: Reader) => Promise<unknown>
    logger: ReturnType<typeof createLogger>
  },
): Promise<{ account: Account; credentials: Credentials } | 'not-connected'> => {
  const account = await accountOf(reader)
  if (!account) return 'not-connected'
  const credentials = openIfReadable(account.credentials)
  if (!credentials) {
    logger.warn('unreadable credentials, connection dropped', { userId: reader })
    await disconnect(reader)
    return 'not-connected'
  }
  return { account, credentials }
}
