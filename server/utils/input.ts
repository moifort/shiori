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
