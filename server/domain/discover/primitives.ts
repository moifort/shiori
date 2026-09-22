import { make } from 'ts-brand'
import { z } from 'zod'
import type { ReleaseDate as ReleaseDateType } from './types'

// A year, a month or a day, and a real one: "2027-02-30" is refused rather than
// kept as a date an alert would never reach.
export const ReleaseDate = (value: unknown) => {
  const v = z
    .string()
    .regex(/^\d{4}(-\d{2}(-\d{2})?)?$/, 'a release date is YYYY, YYYY-MM or YYYY-MM-DD')
    .refine((date) => {
      const [year, month = 1, day = 1] = date.split('-').map(Number)
      const parsed = new Date(Date.UTC(year, month - 1, day))
      return parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === day
    }, 'not a calendar date')
    .parse(value)
  return make<ReleaseDateType>()(v)
}
