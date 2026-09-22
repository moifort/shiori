import type { Subgenre } from '~/domain/book/types'

/** Asks for both sides of every label at once: a write carries at most three,
 *  and the migration sends the whole library's in chunks. */
export const translationPrompt = (labels: readonly Subgenre[]) =>
  `Tu traduis des sous-genres littéraires, ces étiquettes de rayon qui précisent un genre (« Dark Fantasy », « Roman Initiatique », « Cozy Mystery »).

Pour chaque étiquette ci-dessous, écrite en français ou en anglais, donne sa forme française (fr) et sa forme anglaise (en), telles qu'un libraire de chaque pays l'écrirait sur un rayon. Garde le terme d'origine quand c'est l'usage dans l'autre langue (« LitRPG », « Space Opera », « Shōnen »). Réponds dans le même ordre, un élément par étiquette, sans en omettre ni en ajouter.

${labels.map((label, index) => `${index + 1}. ${label}`).join('\n')}`

export const TRANSLATION_SCHEMA = {
  type: 'object',
  properties: {
    subgenres: {
      type: 'array',
      items: {
        type: 'object',
        properties: { fr: { type: 'string' }, en: { type: 'string' } },
        required: ['fr', 'en'],
        propertyOrdering: ['fr', 'en'],
      },
    },
  },
  required: ['subgenres'],
} as const

export type TranslationOutput = { subgenres: { fr: string; en: string }[] }
