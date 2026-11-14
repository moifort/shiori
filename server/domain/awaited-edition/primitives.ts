import { make } from 'ts-brand'
import { z } from 'zod'
import type { AwaitedEditionId as AwaitedEditionIdType } from '~/domain/awaited-edition/types'

export const AwaitedEditionId = (value: unknown) => {
  const v = z.string().min(1).max(600).parse(value)
  return make<AwaitedEditionIdType>()(v)
}
