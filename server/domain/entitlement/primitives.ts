import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  AppAccountToken as AppAccountTokenType,
  OriginalTransactionId as OriginalTransactionIdType,
  ProductId as ProductIdType,
} from '~/domain/entitlement/types'

export const ProductId = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<ProductIdType>()(v)
}

export const OriginalTransactionId = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<OriginalTransactionIdType>()(v)
}

export const AppAccountToken = (value: unknown) => {
  const v = z.uuid().parse(value)
  return make<AppAccountTokenType>()(v)
}
