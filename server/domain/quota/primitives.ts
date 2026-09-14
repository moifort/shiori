import { make } from 'ts-brand'
import { z } from 'zod'
import type { QuotaMonth as QuotaMonthType } from '~/domain/quota/types'

export const QuotaMonth = (value: unknown) => {
  const v = z
    .string()
    .regex(/^\d{4}-\d{2}$/)
    .parse(value)
  return make<QuotaMonthType>()(v)
}
