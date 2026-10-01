import { landingUrlOf, library, login, register } from 'kindle-api-ts'
import type { KindleMarketplace } from '~/domain/kindle/types'

/** The whole surface of `kindle-api-ts` this domain uses, behind one module.
 *
 *  It exists to be mocked: every call here reaches Amazon and would need a real
 *  account to answer. Tests replace this module and nothing else, so the
 *  mapping, the sealing and the write paths are all exercised for real. */
export { library, login, register }

/** Where Amazon sends the browser back once the reader has signed in. The app
 *  watches for exactly this URL to know the sign-in is done. */
export const landingUrlFor = (marketplace: KindleMarketplace): string => landingUrlOf(marketplace)
