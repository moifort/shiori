import { domainError } from '~/domain/shared/graphql/errors'
import { createLogger } from '~/system/logger'

const logger = createLogger('audible')

/** Amazon is a third party that refuses for reasons this server cannot tell
 *  apart — a revoked device, a changed password, a rate limit, an outage. They
 *  all come back as one code with the underlying message attached, because the
 *  app's answer to every one of them is the same: connect again. */
export const audibleUnavailable = (error: unknown): never => {
  // The app hears one code; Sentry hears which of those reasons it was.
  logger.error('Audible call failed', { error })
  return domainError(
    'AUDIBLE_UNAVAILABLE',
    error instanceof Error ? error.message : 'The Audible call failed',
  )
}

export const notConnected = (): never =>
  domainError('AUDIBLE_NOT_CONNECTED', 'No Audible account is connected')
