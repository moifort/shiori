// Per-request count of the Firestore writes a request made, so a scheduled job
// that adds data can be told apart from one that runs for nothing. The meter
// lives on the H3 event context, like the read meter, so the requests an
// instance serves at once never add to each other's count.
//
// Firestore has no write hook either, so the count is taken by wrapping
// `WriteBatch` once, at startup. Every write of the app goes through it: a
// `DocumentReference`'s `create` / `set` / `update` / `delete` commits a batch
// of one, a transaction writes through its own batch, and a `BulkWriter`'s
// batches inherit from it. A write is counted when it is queued: a transaction
// Firestore retries counts its writes once per attempt.

export type WriteMeter = {
  /** `create()`: a document that must not exist yet. */
  creates: number
  /** `set()`: a document created or overwritten, merged or not. */
  sets: number
  /** `update()`: fields changed on a document that exists. */
  updates: number
  deletes: number
}

const currentMeter = (): WriteMeter | undefined => {
  try {
    return useEvent().context._writeMeter as WriteMeter | undefined
  } catch {
    // No request context (e.g. migration scripts, tests) — nothing to count into.
    return undefined
  }
}

/** Start counting the writes of the current request, from zero. Returns the
 *  meter, which keeps counting until the request ends. */
export const startWriteMeter = (context: Record<string, unknown>): WriteMeter => {
  const meter: WriteMeter = { creates: 0, sets: 0, updates: 0, deletes: 0 }
  context._writeMeter = meter
  return meter
}

/** Every document the meter saw written, whatever the kind. */
export const writesOf = ({ creates, sets, updates, deletes }: WriteMeter) =>
  creates + sets + updates + deletes

type Write = (this: unknown, ...args: unknown[]) => unknown
type Writable = { prototype: object }

const wrapped = Symbol('writeMeter')

const meter = (type: Writable, method: string, kind: keyof WriteMeter) => {
  const prototype = type.prototype as Record<string, Write> & { [wrapped]?: Set<string> }
  const write = prototype[method]
  if (typeof write !== 'function') throw new Error(`Firestore has no ${method} to meter`)
  if (!Object.hasOwn(prototype, wrapped)) prototype[wrapped] = new Set()
  if (prototype[wrapped]?.has(method)) return
  prototype[wrapped]?.add(method)
  prototype[method] = function (this: unknown, ...args: unknown[]) {
    // Queued synchronously, then counted: a write Firestore refuses throws here.
    const result = write.apply(this, args)
    const current = currentMeter()
    if (current) current[kind] += 1
    return result
  }
}

/** Wrap the client's write methods so each write adds to the current request's
 *  meter. Idempotent: a second call wraps nothing again. */
export const meterFirestoreWrites = ({ WriteBatch }: { WriteBatch: Writable }) => {
  meter(WriteBatch, 'create', 'creates')
  meter(WriteBatch, 'set', 'sets')
  meter(WriteBatch, 'update', 'updates')
  meter(WriteBatch, 'delete', 'deletes')
}
