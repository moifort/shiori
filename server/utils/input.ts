/** Runs a branded constructor over a value nobody vouches for — a model reading a
 *  cover, a field of somebody else's API — and drops it if it does not validate.
 *
 *  The whole point of the brands is that a hallucinated ISBN or a page count of 0
 *  never reaches the database, and a single bad field must not sink an otherwise
 *  good record. */
export const optionally = <T>(value: unknown, construct: (value: unknown) => T): T | undefined => {
  if (value === null || value === undefined || value === '') return undefined
  try {
    return construct(value)
  } catch {
    return undefined
  }
}

export const isPresent = <T>(value: T | undefined): value is T => value !== undefined
