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

/** The language of a request, read straight off the event.
 *
 *  Reads the header itself rather than through `getHeader`, a Nitro auto-import
 *  that the schema executed outside a server — the feature tests — does not
 *  have. An event with no request, which is what those tests pass, answers
 *  English like a request with no header. */
export const languageOf = (
  event: { node?: { req?: { headers?: { 'accept-language'?: string } } } } | undefined,
): Language => languageFrom(event?.node?.req?.headers?.['accept-language'])
