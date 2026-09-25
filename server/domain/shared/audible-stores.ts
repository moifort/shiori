import type { BookLanguage } from '~/domain/book/types'

/** The Audible store that sells recordings in each language: named in a prompt
 *  so the model looks a recording up where it is listed, rather than guessing
 *  from a general search that misses French ones. */
export const AUDIBLE_STORES: Partial<Record<BookLanguage, string>> = {
  fr: 'audible.fr',
  en: 'audible.com et audible.co.uk',
  de: 'audible.de',
  es: 'audible.es',
  it: 'audible.it',
  ja: 'audible.co.jp',
}
