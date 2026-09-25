import { make } from 'ts-brand'
import { z } from 'zod'
import type { AuthorKey as AuthorKeyType } from '~/domain/author/types'
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
