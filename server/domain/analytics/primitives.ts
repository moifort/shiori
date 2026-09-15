import { make } from 'ts-brand'
import { z } from 'zod'
import type { LocalDate as LocalDateType, TimeZone as TimeZoneType } from './types'

// Validated against the runtime's own time zone database rather than a pattern:
// "Europe/Pariss" has the right shape and would throw on first use.
export const TimeZone = (value: unknown) => {
  const v = z
    .string()
    .min(1)
    .max(100)
    .refine((zone) => {
      try {
        new Intl.DateTimeFormat('en-US', { timeZone: zone })
        return true
      } catch {
        return false
      }
    }, 'unknown time zone')
    .parse(value)
  return make<TimeZoneType>()(v)
}

export const LocalDate = (value: unknown) => {
  const v = z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .parse(value)
  return make<LocalDateType>()(v)
}
