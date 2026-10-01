import { domainError } from '~/domain/shared/graphql/errors'
import { createLogger } from '~/system/logger'

const logger = createLogger('kindle')

/** Amazon is a third party that refuses for reasons this server cannot tell
 *  apart — a deregistered device, a changed password, a page that changed shape,
 *  an outage. They all come back as one code with the underlying message, because
 *  the app's answer to every one of them is the same: connect again. */
export const kindleUnavailable = (error: unknown): never => {
  // The app hears one code; Sentry hears which of those reasons it was.
  logger.error('Kindle call failed', { error })
  return domainError(
    'KINDLE_UNAVAILABLE',
    error instanceof Error ? error.message : 'The Kindle call failed',
  )
}

export const notConnected = (): never =>
  domainError('KINDLE_NOT_CONNECTED', 'No Kindle library is connected')
