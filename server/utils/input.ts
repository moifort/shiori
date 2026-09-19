// Boundary converter: GraphQL nullability → domain "absent key" convention.
//
// Pothos optional input fields are typed as `T | null | undefined`; at runtime
// graphql-js omits absent fields entirely, so the only variant to erase is an
// explicit `null` sent by the client. Domain types use `T?` (a key is present
// with a value, or not present at all) and Firestore rejects `undefined`
// values — dropping the null KEYS (not nulling them) keeps both invariants.
//
// Not recursive: every mutation input in the schema is flat.
type StripNulls<T> = { [K in keyof T]: Exclude<T[K], null> }

export const stripNulls = <T extends Record<string, unknown>>(obj: T): StripNulls<T> => {
  const out: Record<string, unknown> = {}
  for (const key of Object.keys(obj)) {
    const value = (obj as Record<string, unknown>)[key]
    if (value !== null) out[key] = value
  }
  return out as StripNulls<T>
}

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
