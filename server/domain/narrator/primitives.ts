import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  NarratorBiography as NarratorBiographyType,
  NarratorKey as NarratorKeyType,
} from '~/domain/narrator/types'
import { slugify } from '~/utils/slug'

export const NarratorKey = (value: unknown) => {
  const v = z.string().min(1).max(200).parse(value)
  return make<NarratorKeyType>()(v)
}

/** The key a narrator's name folds to, as an author's does: a name written in
 *  a script the slug keeps nothing of falls back to its trimmed lowercase self. */
export const narratorKeyOf = (name: string): NarratorKeyType =>
  NarratorKey(slugify(name) || name.trim().toLowerCase())

export const NarratorBiography = (value: unknown) => {
  const v = z.string().trim().min(1).max(2000).parse(value)
  return make<NarratorBiographyType>()(v)
}
