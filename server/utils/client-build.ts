/** Which client sent a request, from its user agent: its first token, the
 *  app and its build (`Shiori/1572`, `okhttp/5.3.0`).
 *
 *  A build run from Xcode — the simulator of the captures and the board's
 *  sessions — keeps the project's build number, 1; the TestFlight and App Store
 *  builds carry the one CI stamps. Production answers both alike, but the
 *  operation lines say which is which, so that a count of readers can leave
 *  the development runs out. */
export const clientBuildOf = (
  userAgent: string | undefined,
): { client: string; debugBuild: boolean } => {
  const client = userAgent?.trim().split(/\s+/)[0] || 'unknown'
  return { client, debugBuild: client === 'Shiori/1' }
}

/** The user agent of a request, read straight off the event, like
 *  `languageOf`: the feature tests run the schema with no server to provide
 *  Nitro's `getHeader`. */
export const userAgentOf = (
  event: { node?: { req?: { headers?: { 'user-agent'?: string } } } } | undefined,
): string | undefined => event?.node?.req?.headers?.['user-agent']
