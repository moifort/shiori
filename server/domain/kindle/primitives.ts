import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  KindleAsin as KindleAsinType,
  KindleMarketplace,
  SealedKindleCredentials as SealedKindleCredentialsType,
} from '~/domain/kindle/types'
import { KINDLE_MARKETPLACES } from '~/domain/kindle/types'

// Amazon's product identifier: ten characters, alphanumeric, upper case. Bounded
// at the door because the app hands it back as the list of titles to import.
export const KindleAsin = (value: unknown) => {
  const v = z
    .string()
    .regex(/^[A-Z0-9]{10}$/, 'an ASIN is ten upper-case alphanumeric characters')
    .parse(value)
  return make<KindleAsinType>()(v)
}

export const KindleMarketplaceValue = (value: unknown): KindleMarketplace =>
  z.enum(KINDLE_MARKETPLACES).parse(value)

export const SealedKindleCredentials = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<SealedKindleCredentialsType>()(v)
}
