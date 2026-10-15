// Per-request count of the Firestore reads a request made, so a slow screen can
// be told apart from an expensive one. The meter lives on the H3 event context,
// like the request cache, so the requests an instance serves at once never add
// to each other's count. Requires `experimental.asyncContext`.
//
// Firestore has no read hook, so the count is taken by wrapping the client's
// public read methods once, at startup. Every read of the app goes through one
// of them: `DocumentReference.get()` is itself a `Firestore.getAll()` of one,
// and a transaction reads through its own methods, never through those.

export type ReadMeter = {
  /** Documents fetched by reference: `get()`, `getAll()`, a transaction's read. */
  docReads: number
  /** Query round-trips, aggregations included. */
  queryReads: number
  /** Documents the queries returned — with `docReads`, what Firestore bills. */
  queryDocs: number
}

const currentMeter = (): ReadMeter | undefined => {
  try {
    return useEvent().context._readMeter as ReadMeter | undefined
  } catch {
    // No request context (e.g. migration scripts, tests) — nothing to count into.
    return undefined
  }
}

/** Start counting the reads of the current request, from zero. Returns the
 *  meter, which keeps counting until the request ends. */
export const startReadMeter = (context: Record<string, unknown>): ReadMeter => {
  const meter: ReadMeter = { docReads: 0, queryReads: 0, queryDocs: 0 }
  context._readMeter = meter
  return meter
}

type Read = (this: unknown, ...args: unknown[]) => Promise<unknown>
type Readable = { prototype: object }

/** What the wrapped methods read, told from their arguments and their answer. */
type Tally = (meter: ReadMeter, args: unknown[], result: unknown) => void

const sizeOf = (result: unknown) => (result as { size?: number } | undefined)?.size ?? 0

const byReference: Tally = (meter, args) => {
  // `getAll` takes the references, then optionally a `{ fieldMask }`.
  meter.docReads += args.filter((arg) => (arg as { path?: unknown })?.path !== undefined).length
}

const byQuery: Tally = (meter, _args, result) => {
  meter.queryReads += 1
  meter.queryDocs += sizeOf(result)
}

const wrapped = Symbol('readMeter')

const meter = (type: Readable, method: string, tally: Tally) => {
  const prototype = type.prototype as Record<string, Read> & { [wrapped]?: Set<string> }
  const read = prototype[method]
  if (typeof read !== 'function') throw new Error(`Firestore has no ${method} to meter`)
  if (!Object.hasOwn(prototype, wrapped)) prototype[wrapped] = new Set()
  if (prototype[wrapped]?.has(method)) return
  prototype[wrapped]?.add(method)
  prototype[method] = function (this: unknown, ...args: unknown[]) {
    // Taken before the read starts: the request context is certain here.
    const current = currentMeter()
    const pending = read.apply(this, args)
    if (!current) return pending
    return pending.then((result) => {
      tally(current, args, result)
      return result
    })
  }
}

/** The Firestore client classes whose reads are metered. */
export type FirestoreClasses = {
  Firestore: Readable
  Query: Readable
  AggregateQuery: Readable
  Transaction: Readable
  DocumentReference: Readable
}

/** Wrap the client's read methods so each read adds to the current request's
 *  meter. Idempotent: a second call wraps nothing again. */
export const meterFirestoreReads = (classes: FirestoreClasses) => {
  const { Firestore, Query, AggregateQuery, Transaction, DocumentReference } = classes
  meter(Firestore, 'getAll', byReference)
  meter(Query, 'get', byQuery)
  meter(AggregateQuery, 'get', (current) => {
    current.queryReads += 1
  })
  meter(Transaction, 'getAll', byReference)
  meter(Transaction, 'get', (current, [target], result) => {
    if (target instanceof (DocumentReference as unknown as new () => object)) current.docReads += 1
    else if (target instanceof (Query as unknown as new () => object)) byQuery(current, [], result)
    else current.queryReads += 1
  })
}
