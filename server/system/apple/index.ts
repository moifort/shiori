import {
  Environment,
  type JWSTransactionDecodedPayload,
  SignedDataVerifier,
  VerificationException,
  VerificationStatus,
} from '@apple/app-store-server-library'
import { appleRootCertificates } from '~/system/apple/root-certificates'
import type { AppleNotification, AppleTransaction } from '~/system/apple/types'
import { APP_STORE_ID, BUNDLE_ID } from '~/system/apple/types'
import { config } from '~/system/config/index'
import { createLogger } from '~/system/logger'

const logger = createLogger('apple')

// Which App Store a signature may come from. A shipped app receives both at once
// — TestFlight and review sign in Sandbox, the App Store in Production — so both
// are always tried, unless a single environment is pinned
// (`NITRO_APPLE_ENVIRONMENT`, set to `Xcode` for the local StoreKit configuration
// file, whose payloads are signed by a throwaway local certificate and cannot
// chain to Apple's roots).
//
// Exported for the test that guards the Production path: Apple's verifier rejects
// a Production signature outright when checked against Sandbox, so dropping
// Production here means turning away every paying subscriber.
export const verificationEnvironments = (): Environment[] => {
  const { appleEnvironment } = config()
  if (appleEnvironment) return [appleEnvironment]
  return [Environment.PRODUCTION, Environment.SANDBOX]
}

// One verifier per environment, rebuilt per call: they are cheap, and a cached
// one would outlive a configuration change in a long-running instance.
const verifierFor = (environment: Environment) =>
  new SignedDataVerifier(
    appleRootCertificates(),
    // Online revocation checks call out to Apple on every verification. Off: a
    // revoked receipt reaches us through the notification webhook, which is the
    // channel built for it.
    false,
    environment,
    BUNDLE_ID,
    APP_STORE_ID,
  )

// Apple's own refusal carries a status code and an empty message, so it is named
// rather than printed: `INVALID_ENVIRONMENT` (the signature is for the other App
// Store) reads nothing like `INVALID_CERTIFICATE`.
const refusalOf = (error: unknown): string =>
  error instanceof VerificationException
    ? (VerificationStatus[error.status] ?? String(error.status))
    : error instanceof Error
      ? error.message
      : String(error)

// Apple's library throws on an unverifiable payload; the domain speaks in
// sentinels, so the boundary converts. Every environment is tried before giving
// up — a payload signed for Sandbox simply fails the Production verifier.
//
// Building the verifier is inside the try as well: it throws on anything it
// cannot honour, and that must read as "this did not verify", never as a crash on
// the purchase path.
//
// A payload nobody can verify is logged with the reason each environment gave:
// without it, a refused purchase is indistinguishable from a misconfiguration,
// and the subscriber's money is already gone.
const verifyAcrossEnvironments = async <T>(
  verify: (verifier: SignedDataVerifier) => Promise<T>,
): Promise<T | 'invalid-signature'> => {
  const refusals: string[] = []
  for (const environment of verificationEnvironments()) {
    try {
      return await verify(verifierFor(environment))
    } catch (error) {
      refusals.push(`${environment}: ${refusalOf(error)}`)
    }
  }
  logger.warn(`Apple signed data verified by no environment (${refusals.join(', ')})`)
  return 'invalid-signature'
}

// Apple's payload → the shape the domain acts on. A transaction with no product
// or no original id is not one we can attach to an account.
const toTransaction = (payload: JWSTransactionDecodedPayload): AppleTransaction | undefined =>
  payload.productId && payload.originalTransactionId
    ? {
        productId: payload.productId,
        originalTransactionId: payload.originalTransactionId,
        ...(payload.appAccountToken ? { appAccountToken: payload.appAccountToken } : {}),
        ...(payload.expiresDate ? { expiresAt: new Date(payload.expiresDate) } : {}),
        ...(payload.revocationDate ? { revokedAt: new Date(payload.revocationDate) } : {}),
      }
    : undefined

export namespace Apple {
  // Check a signed transaction handed over by the app and decode what it grants.
  // This is the only thing standing between a client claim and Premium: the
  // signature proves Apple sold it, and nothing here trusts the caller.
  export const verifyTransaction = async (
    signedTransaction: string,
  ): Promise<AppleTransaction | 'invalid-signature'> => {
    const payload = await verifyAcrossEnvironments((verifier) =>
      verifier.verifyAndDecodeTransaction(signedTransaction),
    )
    if (payload === 'invalid-signature') return 'invalid-signature'
    return toTransaction(payload) ?? 'invalid-signature'
  }

  // Check a signed App Store Server Notification and decode the transaction it
  // carries. Same signature check: the webhook is unauthenticated by design, its
  // only proof of origin is this.
  export const verifyNotification = async (
    signedPayload: string,
  ): Promise<AppleNotification | 'invalid-signature'> => {
    const payload = await verifyAcrossEnvironments((verifier) =>
      verifier.verifyAndDecodeNotification(signedPayload),
    )
    if (payload === 'invalid-signature') return 'invalid-signature'

    const signedTransaction = payload.data?.signedTransactionInfo
    const transaction = signedTransaction
      ? await verifyTransaction(signedTransaction)
      : 'invalid-signature'
    return {
      type: payload.notificationType ?? 'UNKNOWN',
      ...(payload.subtype ? { subtype: payload.subtype } : {}),
      ...(transaction === 'invalid-signature' ? {} : { transaction }),
    }
  }
}
