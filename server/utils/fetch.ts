/** Whether a fetch failed because its `AbortSignal.timeout` ran out, rather than
 *  because the host could not be reached or answered badly. The platform throws a
 *  `DOMException` named `TimeoutError` for it, with no subclass to test against. */
export const isTimeout = (error: unknown): boolean =>
  error instanceof DOMException && error.name === 'TimeoutError'
