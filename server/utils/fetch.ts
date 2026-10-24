/** Whether a fetch failed because its `AbortSignal.timeout` ran out, rather than
 *  because the host could not be reached or answered badly. The platform throws a
 *  `DOMException` named `TimeoutError` for it, with no subclass to test against. */
export const isTimeout = (error: unknown): boolean =>
  error instanceof DOMException && error.name === 'TimeoutError'

/** Whether a fetch failed because the resolver could not answer for the host in
 *  time — `getaddrinfo EAI_AGAIN`, an answer that asks to be tried again — rather
 *  than because the host does not exist or refused the connection. Node's fetch
 *  wraps it as a `TypeError` whose cause carries the code. */
export const isTemporaryDnsFailure = (error: unknown): boolean =>
  (error as { cause?: { code?: unknown } } | undefined)?.cause?.code === 'EAI_AGAIN'
