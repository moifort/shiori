import { createHash } from 'node:crypto'
import { make } from 'ts-brand'
import { z } from 'zod'
import type { ImageHash as ImageHashType } from '~/domain/scan/types'
import type { Language } from '~/domain/shared/language'
import { SUPPORTED_LANGUAGES } from '~/domain/shared/language'

export const ImageHash = (value: unknown) => {
  const v = z
    .string()
    .regex(/^[a-f0-9]{64}$/, 'image hash must be a hex SHA-256')
    .parse(value)
  return make<ImageHashType>()(v)
}

export const hashImage = (image: Buffer): ImageHashType =>
  ImageHash(createHash('sha256').update(image).digest('hex'))

export const ScanLanguage = (value: unknown): Language => z.enum(SUPPORTED_LANGUAGES).parse(value)
