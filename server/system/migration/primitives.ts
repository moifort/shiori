import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  MigrationName as MigrationNameType,
  MigrationVersion as MigrationVersionType,
} from '~/system/migration/types'

export const MigrationVersion = (value: unknown) => {
  const validatedValue = z
    .preprocess((v) => (typeof v === 'string' ? Number(v) : v), z.number().int().min(0))
    .parse(value)
  return make<MigrationVersionType>()(validatedValue)
}

export const MigrationName = (value: unknown) => {
  const validatedValue = z.string().min(1).parse(value)
  return make<MigrationNameType>()(validatedValue)
}
