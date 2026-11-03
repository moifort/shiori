import { make } from 'ts-brand'
import { z } from 'zod'
import type { WishId as WishIdType } from './types'

export const WishId = (value: unknown) => {
  const v = z.string().min(1).max(600).parse(value)
  return make<WishIdType>()(v)
}
