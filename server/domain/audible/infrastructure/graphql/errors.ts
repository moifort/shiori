import { domainError } from '~/domain/shared/graphql/errors'

/** Amazon is a third party that refuses for reasons this server cannot tell
 *  apart — a revoked device, a changed password, a rate limit, an outage. They
 *  all come back as one code with the underlying message attached, because the
 *  app's answer to every one of them is the same: connect again. */
export const audibleUnavailable = (error: unknown): never =>
  domainError(
    'AUDIBLE_UNAVAILABLE',
    error instanceof Error ? error.message : 'The Audible call failed',
  )

export const notConnected = (): never =>
  domainError('AUDIBLE_NOT_CONNECTED', 'No Audible account is connected')
