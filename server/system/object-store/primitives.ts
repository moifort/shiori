import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  ByteSize as ByteSizeType,
  ContentType as ContentTypeType,
  ObjectPath as ObjectPathType,
  SignedUrl as SignedUrlType,
} from '~/system/object-store/types'

// Rejects the traversal outright rather than sanitizing it: a path containing
// `..` never comes from this codebase, so it is a caller trying something.
export const ObjectPath = (value: unknown) => {
  const v = z
    .string()
    .min(1)
    .refine((path) => !path.includes('..'), 'object path must not traverse')
    .parse(value)
  return make<ObjectPathType>()(v)
}

export const SignedUrl = (value: unknown) => {
  const v = z.string().url().parse(value)
  return make<SignedUrlType>()(v)
}

export const ContentType = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<ContentTypeType>()(v)
}

export const ByteSize = (value: unknown) => {
  const v = z.number().int().nonnegative().parse(value)
  return make<ByteSizeType>()(v)
}
