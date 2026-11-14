import { createError, defineEventHandler, readBody } from 'h3'
import { match } from 'ts-pattern'
import { EntitlementUseCase } from '~/domain/entitlement/use-case'

// Where Apple tells us a subscription renewed, lapsed or was refunded, without
// waiting for the app to open (App Store Server Notifications V2). Declared once
// in App Store Connect; Apple retries for hours on any non-2xx, so a payload we
// cannot act on is still acknowledged — only an unverifiable signature is refused.
//
// Unauthenticated by design (see the auth middleware): the caller is Apple, and
// the proof is the signature on the payload itself, checked in
// `EntitlementUseCase.applyNotification`. h3 is imported rather than relied on as
// a Nitro auto-import so the handler runs under test as it runs in the server.
export default defineEventHandler(async (event) => {
  const body = await readBody<{ signedPayload?: unknown } | undefined>(event)
  const signedPayload = body?.signedPayload
  if (typeof signedPayload !== 'string' || signedPayload === '')
    throw createError({ statusCode: 400, statusMessage: 'Missing payload' })

  const result = await EntitlementUseCase.applyNotification(signedPayload)
  return match(result)
    .with('invalid-notification', () => {
      throw createError({ statusCode: 401, statusMessage: 'Unverified notification' })
    })
    .with('applied', () => ({ status: 'applied' }))
    .with('ignored', () => ({ status: 'ignored' }))
    .exhaustive()
})
