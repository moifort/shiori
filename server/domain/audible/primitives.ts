import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  AudibleMarketplace,
  SealedCredentials as SealedCredentialsType,
} from '~/domain/audible/types'
import { AUDIBLE_MARKETPLACES } from '~/domain/audible/types'

export const AudibleMarketplaceValue = (value: unknown): AudibleMarketplace =>
  z.enum(AUDIBLE_MARKETPLACES).parse(value)

export const SealedCredentials = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<SealedCredentialsType>()(v)
}
