import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  AuthorBiography as AuthorBiographyType,
  AuthorKey as AuthorKeyType,
  Nationality as NationalityType,
  PortraitUrl as PortraitUrlType,
} from '~/domain/author/types'
import { slugify } from '~/utils/slug'

export const AuthorKey = (value: unknown) => {
  const v = z.string().min(1).max(200).parse(value)
  return make<AuthorKeyType>()(v)
}

/** The key an author name folds to. A name written in a script the slug keeps
 *  nothing of — 村上春樹 — falls back to its trimmed lowercase self, or every
 *  Japanese author would fold to the same empty key. */
export const authorKeyOf = (name: string): AuthorKeyType =>
  AuthorKey(slugify(name) || name.trim().toLowerCase())

export const AuthorBiography = (value: unknown) => {
  const v = z.string().trim().min(1).max(2000).parse(value)
  return make<AuthorBiographyType>()(v)
}

export const Nationality = (value: unknown) => {
  const v = z.string().trim().min(1).max(100).parse(value)
  return make<NationalityType>()(v)
}

export const PortraitUrl = (value: unknown) => {
  const v = z
    .string()
    .url()
    .refine((url) => url.startsWith('https://'), 'portrait URL must be HTTPS')
    .parse(value)
  return make<PortraitUrlType>()(v)
}
