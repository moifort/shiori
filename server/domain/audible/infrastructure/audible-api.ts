import { AUDIBLE_LOCALES, library, login, register } from 'audible-api-ts'
import type { AudibleMarketplace } from '~/domain/audible/types'

/** The whole surface of `audible-api-ts` this domain uses, behind one module.
 *
 *  It exists to be mocked: every call here reaches Amazon, signs a request with a
 *  device key and would need a real account to answer. Tests replace this module
 *  and nothing else, so the mapping, the sealing and the write paths are all
 *  exercised for real. */
export { library, login, register }

/** Where Amazon sends the browser back once the reader has signed in. The
 *  authorization code rides on it as a query parameter, and the app watches for
 *  exactly this URL to know the sign-in is done. */
export const landingUrlOf = (marketplace: AudibleMarketplace): string =>
  `https://www.amazon.${AUDIBLE_LOCALES[marketplace].domain}/ap/maplanding`
