import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  AudibleAsin as AudibleAsinType,
  AudibleMarketplace,
  SealedCredentials as SealedCredentialsType,
} from '~/domain/audible/types'
import { AUDIBLE_MARKETPLACES } from '~/domain/audible/types'

// Amazon's product identifier: ten characters, alphanumeric, upper case. Bounded
// at the door because it is handed back by the app as the list of titles to
// import, and it addresses a row in somebody's Amazon library.
export const AudibleAsin = (value: unknown) => {
  const v = z
    .string()
    .regex(/^[A-Z0-9]{10}$/, 'an ASIN is ten upper-case alphanumeric characters')
    .parse(value)
  return make<AudibleAsinType>()(v)
}

export const AudibleMarketplaceValue = (value: unknown): AudibleMarketplace =>
  z.enum(AUDIBLE_MARKETPLACES).parse(value)

export const SealedCredentials = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<SealedCredentialsType>()(v)
}
