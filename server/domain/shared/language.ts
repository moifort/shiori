// The languages the app is localized into. French and English ship at launch; the
// machinery is sized for more, so adding a market is filling in strings rather
// than reworking anything. Used to pick the language of whatever the backend
// renders for the client (AI scan text, the served changelog), driven by the
// request's `Accept-Language`.
export const SUPPORTED_LANGUAGES = ['fr', 'en'] as const

export type Language = (typeof SUPPORTED_LANGUAGES)[number]

// Resolve an `Accept-Language` header to a supported language. Reads only the
// primary subtag of the first listed language (`fr-CH,fr;q=0.9` -> `fr`) and falls
// back to English for anything unsupported.
export const languageFrom = (acceptLanguage: string | undefined): Language => {
  const primary = acceptLanguage?.split(',')[0]?.trim().split('-')[0]?.toLowerCase()
  return SUPPORTED_LANGUAGES.includes(primary as Language) ? (primary as Language) : 'en'
}
