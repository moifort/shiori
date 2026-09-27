import type { BookLanguage } from '~/domain/book/types'

/** The Amazon store that sells the books of each language: where a printed
 *  volume's release day is read, and named in a prompt so the model looks it
 *  up there. */
export const AMAZON_STORES: Partial<Record<BookLanguage, string>> = {
  fr: 'amazon.fr',
  en: 'amazon.com',
  de: 'amazon.de',
  es: 'amazon.es',
  it: 'amazon.it',
  nl: 'amazon.nl',
  pl: 'amazon.pl',
  sv: 'amazon.se',
  tr: 'amazon.com.tr',
  ja: 'amazon.co.jp',
}
