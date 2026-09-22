/**
 * In-memory Firestore fake for unit tests. Records every created batch and every
 * direct (non-batched) write so tests can assert the atomicity contract: all
 * writes of an operation enlisted into one batch, committed exactly once, and
 * nothing applied when the commit fails.
 *
 * Test files mock the firebase module with the shared holder so file ordering
 * does not matter:
 *   mock.module('~/system/firebase', () => ({ db: fakeDb }))
 */
import { FieldValue, type Firestore } from 'firebase-admin/firestore'

type Doc = Record<string, unknown>

export type FakeSnapshot = { exists: boolean; id: string; data: () => Doc | undefined }

export type FakeRef = {
  /** The collection holding this document. Collections are flat, never nested. */
  collectionPath: string
  id: string
  get: () => Promise<FakeSnapshot>
  set: (data: Doc, options?: { merge?: boolean }) => Promise<void>
  update: (data: Doc) => Promise<void>
  delete: () => Promise<void>
}

export type BatchOp =
  | { type: 'set'; ref: FakeRef; data: Doc }
  | { type: 'update'; ref: FakeRef; data: Doc }
  | { type: 'merge'; ref: FakeRef; data: Doc }
  | { type: 'delete'; ref: FakeRef }

export type FakeBatch = {
  ops: BatchOp[]
  commits: number
  set: (ref: FakeRef, data: Doc, options?: { merge?: boolean }) => FakeBatch
  update: (ref: FakeRef, data: Doc) => FakeBatch
  delete: (ref: FakeRef) => FakeBatch
  commit: () => Promise<void>
}

export type FakeTransaction = {
  get: (ref: FakeRef) => Promise<FakeSnapshot>
  set: (ref: FakeRef, data: Doc) => FakeTransaction
  delete: (ref: FakeRef) => FakeTransaction
}

export type DirectWrite = { type: 'set' | 'update' | 'delete'; collection: string; id: string }

type FakeQuery = {
  where: (field: string, op: string, value: unknown) => FakeQuery
  orderBy: (field: string, direction?: 'asc' | 'desc') => FakeQuery
  limit: (count: number) => FakeQuery
  offset: (count: number) => FakeQuery
  startAfter: (cursor: FakeSnapshot) => FakeQuery
  get: () => Promise<{ docs: Array<{ data: () => Doc; ref: FakeRef }> }>
  count: () => { get: () => Promise<{ data: () => { count: number } }> }
}

type FakeCollection = {
  withConverter: (converter: unknown) => FakeCollection
  doc: (id?: string) => FakeRef
  add: (data: Doc) => Promise<FakeRef>
  where: FakeQuery['where']
  orderBy: FakeQuery['orderBy']
  limit: FakeQuery['limit']
  get: FakeQuery['get']
  count: FakeQuery['count']
}

export const createFakeFirestore = () => {
  const store = new Map<string, Map<string, Doc>>()
  const batches: FakeBatch[] = []
  const directWrites: DirectWrite[] = []
  // The writes each committed transaction applied, in order — lets a test prove a
  // read-modify-write went through one transaction rather than a bare set.
  const transactions: BatchOp[][] = []
  let commitError: Error | undefined
  let generatedIds = 0
  let docReads = 0
  let queryReads = 0
  // Documents a query returned: what Firestore actually bills a query for.
  let queriedDocs = 0
  // Handed to the next query instead of an answer, once.
  let queryError: Error | undefined

  const docsOf = (collection: string) => {
    const existing = store.get(collection)
    if (existing) return existing
    const created = new Map<string, Doc>()
    store.set(collection, created)
    return created
  }

  // Resolve a document write the way Firestore does: FieldValue.increment
  // sentinels add to the stored number (`operand` is the transform's runtime
  // field), nested maps recurse, and a merge keeps whatever the write does not
  // name. Only direct ref.set supports this — no production code sends
  // transforms through a batch or a transaction.
  const resolveWrite = (existing: Doc | undefined, data: Doc, merge: boolean): Doc => {
    const result: Doc = merge ? { ...(existing ?? {}) } : {}
    for (const [key, value] of Object.entries(data)) {
      const current = merge ? existing?.[key] : undefined
      if (value instanceof FieldValue && 'operand' in value) {
        const operand = (value as unknown as { operand: number }).operand
        result[key] = (typeof current === 'number' ? current : 0) + operand
      } else if (
        value &&
        typeof value === 'object' &&
        !(value instanceof Date) &&
        !Array.isArray(value)
      ) {
        result[key] = resolveWrite(current as Doc | undefined, value as Doc, merge)
      } else {
        result[key] = value
      }
    }
    return result
  }

  // Firestore rejects `undefined` anywhere in a document, including inside an
  // array. The fake used to accept it, which let a real bug pass a green test:
  // a series catalogue with one unnumbered volume wrote fine here and was
  // refused in production. Rejecting it makes the fake honest.
  const rejectUndefined = (value: unknown, path: string): void => {
    if (value === undefined) {
      throw new Error(`Cannot use "undefined" as a Firestore value (found at ${path})`)
    }
    if (Array.isArray(value)) {
      for (const [index, entry] of value.entries()) rejectUndefined(entry, `${path}[${index}]`)
      return
    }
    if (value === null || typeof value !== 'object' || value instanceof Date) return
    if (value instanceof FieldValue) return
    for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
      rejectUndefined(entry, path ? `${path}.${key}` : key)
    }
  }

  const makeRef = (collection: string, id: string): FakeRef => ({
    collectionPath: collection,
    id,
    get: async () => {
      docReads += 1
      const doc = docsOf(collection).get(id)
      return { exists: doc !== undefined, id, data: () => doc }
    },
    set: async (data, options) => {
      rejectUndefined(data, `${collection}/${id}`)
      directWrites.push({ type: 'set', collection, id })
      docsOf(collection).set(
        id,
        resolveWrite(docsOf(collection).get(id), data, options?.merge === true),
      )
    },
    // Like Firestore's update: merges into an existing document, and refuses to
    // create one. A caller racing with a deletion must fail, not resurrect a
    // ghost document holding only the field it wrote.
    update: async (data) => {
      const existing = docsOf(collection).get(id)
      if (existing === undefined) {
        throw new Error(`NOT_FOUND: no document to update at ${collection}/${id}`)
      }
      directWrites.push({ type: 'update', collection, id })
      docsOf(collection).set(id, resolveWrite(existing, data, true))
    },
    delete: async () => {
      directWrites.push({ type: 'delete', collection, id })
      docsOf(collection).delete(id)
    },
  })

  const sortValue = (value: unknown) =>
    value instanceof Date ? value.getTime() : (value as number | string)

  type Filter = [field: string, op: string, value: unknown]
  type QueryState = {
    filters: Filter[]
    orders: { field: string; direction: 'asc' | 'desc' }[]
    limit?: number
    offset?: number
    startAfter?: { id: string; data: Doc | undefined }
  }

  // Only the operators production code actually uses — fail loudly otherwise.
  const matchesFilter = (data: Doc, [field, op, value]: Filter) => {
    if (op === '==') return data[field] === value
    if (op === '!=') return data[field] !== undefined && data[field] !== value
    if (op === 'in') return Array.isArray(value) && value.includes(data[field])
    const held = data[field]
    if (op === 'array-contains') return Array.isArray(held) && held.includes(value)
    if (op === 'array-contains-any')
      return (
        Array.isArray(held) && Array.isArray(value) && value.some((wanted) => held.includes(wanted))
      )
    throw new Error(
      `fake-firestore only supports '==', '!=', 'in', 'array-contains' and ` +
        `'array-contains-any' queries, got '${op}'`,
    )
  }

  const makeQuery = (collection: string, state: QueryState): FakeQuery => ({
    where: (field, op, value) =>
      makeQuery(collection, { ...state, filters: [...state.filters, [field, op, value]] }),
    orderBy: (field, direction = 'asc') =>
      makeQuery(collection, { ...state, orders: [...state.orders, { field, direction }] }),
    limit: (count) => makeQuery(collection, { ...state, limit: count }),
    offset: (count) => makeQuery(collection, { ...state, offset: count }),
    startAfter: (cursor) =>
      makeQuery(collection, { ...state, startAfter: { id: cursor.id, data: cursor.data() } }),
    get: async () => {
      if (queryError) {
        const error = queryError
        queryError = undefined
        throw error
      }
      queryReads += 1
      let matching = [...docsOf(collection).entries()].filter(([, data]) =>
        state.filters.every((filter) => matchesFilter(data, filter)),
      )
      if (state.orders.length > 0) {
        const { orders } = state
        // Firestore leaves out a document missing an ordered field — mirror it,
        // so a record a migration forgot is as invisible here as in production.
        matching = matching.filter(([, data]) => orders.every(({ field }) => field in data))
        const compared = (left: unknown, right: unknown) => {
          const [a, b] = [sortValue(left), sortValue(right)]
          return a < b ? -1 : a > b ? 1 : 0
        }
        // Firestore uses the document id as an implicit tie-break, in the
        // direction of the last ordering — mirror it.
        const last = orders.at(-1)?.direction ?? 'asc'
        const inOrder = ([idA, a]: [string, Doc], [idB, b]: [string, Doc]) => {
          for (const { field, direction } of orders) {
            const comparison = compared(a[field], b[field])
            if (comparison !== 0) return direction === 'desc' ? -comparison : comparison
          }
          const tie = compared(idA, idB)
          return last === 'desc' ? -tie : tie
        }
        matching.sort(inOrder)
        // A snapshot cursor positions by the values it holds, as Firestore's
        // does: the cursor need not match the filters, nor still be stored.
        const cursor = state.startAfter
        if (cursor?.data)
          matching = matching.filter((row) => inOrder(row, [cursor.id, cursor.data as Doc]) > 0)
      } else if (state.startAfter) {
        const cursorIndex = matching.findIndex(([id]) => id === state.startAfter?.id)
        if (cursorIndex >= 0) matching = matching.slice(cursorIndex + 1)
      }
      if (state.offset !== undefined) matching = matching.slice(state.offset)
      if (state.limit !== undefined) matching = matching.slice(0, state.limit)
      queriedDocs += matching.length
      return {
        docs: matching.map(([id, data]) => ({ data: () => data, ref: makeRef(collection, id) })),
      }
    },
    // Aggregation count: like Firestore, one billed query round-trip, no documents.
    count: () => ({
      get: async () => {
        queryReads += 1
        const matching = [...docsOf(collection).values()].filter((data) =>
          state.filters.every((filter) => matchesFilter(data, filter)),
        )
        return { data: () => ({ count: matching.length }) }
      },
    }),
  })

  const makeCollection = (name: string): FakeCollection => ({
    withConverter: () => makeCollection(name),
    doc: (id) => makeRef(name, id ?? `generated-${++generatedIds}`),
    add: async (data) => {
      const ref = makeRef(name, `generated-${++generatedIds}`)
      await ref.set(data)
      return ref
    },
    where: (field, op, value) => makeQuery(name, { filters: [[field, op, value]], orders: [] }),
    orderBy: (field, direction) =>
      makeQuery(name, { filters: [], orders: [] }).orderBy(field, direction),
    limit: (count) => makeQuery(name, { filters: [], orders: [] }).limit(count),
    get: () => makeQuery(name, { filters: [], orders: [] }).get(),
    count: () => makeQuery(name, { filters: [], orders: [] }).count(),
  })

  const makeBatch = (): FakeBatch => {
    const ops: BatchOp[] = []
    const batch: FakeBatch = {
      ops,
      commits: 0,
      // A merge set is recorded as an update that may create the document, which is
      // what Firestore does with `{ merge: true }`.
      set: (ref, data, options) => {
        ops.push(options?.merge ? { type: 'merge', ref, data } : { type: 'set', ref, data })
        return batch
      },
      update: (ref, data) => {
        ops.push({ type: 'update', ref, data })
        return batch
      },
      delete: (ref) => {
        ops.push({ type: 'delete', ref })
        return batch
      },
      commit: async () => {
        if (commitError) throw commitError
        // Firestore refuses a batch of more than 500 writes outright.
        if (ops.length > 500)
          throw new Error(`INVALID_ARGUMENT: ${ops.length} writes in one batch, 500 at most`)
        for (const op of ops) {
          if (op.type === 'set') docsOf(op.ref.collectionPath).set(op.ref.id, op.data)
          else if (op.type === 'merge') {
            const existing = docsOf(op.ref.collectionPath).get(op.ref.id)
            docsOf(op.ref.collectionPath).set(op.ref.id, resolveWrite(existing, op.data, true))
          } else if (op.type === 'update') {
            const existing = docsOf(op.ref.collectionPath).get(op.ref.id)
            if (existing === undefined) {
              throw new Error(
                `NOT_FOUND: no document to update at ${op.ref.collectionPath}/${op.ref.id}`,
              )
            }
            docsOf(op.ref.collectionPath).set(op.ref.id, resolveWrite(existing, op.data, true))
          } else docsOf(op.ref.collectionPath).delete(op.ref.id)
        }
        batch.commits += 1
      },
    }
    batches.push(batch)
    return batch
  }

  // Transactions run one after another rather than concurrently. Real Firestore
  // aborts and retries the loser of a contended write; serialising the bodies
  // reaches the same end state and makes a concurrency test deterministic instead
  // of retry-dependent.
  let transactionQueue: Promise<unknown> = Promise.resolve()

  const runTransaction = <T>(run: (tx: FakeTransaction) => Promise<T>): Promise<T> => {
    const result = transactionQueue.then(async () => {
      const writes: BatchOp[] = []
      const tx: FakeTransaction = {
        get: async (ref) => {
          docReads += 1
          const doc = docsOf(ref.collectionPath).get(ref.id)
          return { exists: doc !== undefined, id: ref.id, data: () => doc }
        },
        set: (ref, data) => {
          writes.push({ type: 'set', ref, data })
          return tx
        },
        delete: (ref) => {
          writes.push({ type: 'delete', ref })
          return tx
        },
      }
      const value = await run(tx)
      // Applied only once the body succeeded — a throw leaves the store untouched.
      for (const op of writes) {
        if (op.type === 'set') docsOf(op.ref.collectionPath).set(op.ref.id, op.data)
        else docsOf(op.ref.collectionPath).delete(op.ref.id)
      }
      transactions.push(writes)
      return value
    })
    // The queue must keep flowing even when a transaction throws, or every later
    // one would inherit the rejection.
    transactionQueue = result.catch(() => undefined)
    return result
  }

  const getAll = async (...refs: FakeRef[]) => {
    docReads += refs.length
    return refs.map((ref) => {
      const doc = docsOf(ref.collectionPath).get(ref.id)
      return { exists: doc !== undefined, id: ref.id, data: () => doc }
    })
  }

  return {
    db: {
      collection: makeCollection,
      batch: makeBatch,
      getAll,
      runTransaction,
    } as unknown as Firestore,
    seed: (collection: string, id: string, data: Doc) => {
      docsOf(collection).set(id, { ...data })
    },
    snapshot: (collection: string) => new Map(docsOf(collection)),
    /** One stored document, or null. Subcollections are addressed by their full
     *  path, e.g. `users/reader-1/books`. */
    data: (collection: string, id: string) => docsOf(collection).get(id) ?? null,
    batches,
    directWrites,
    transactions,
    // Firestore round-trips (document gets + query gets) — lets tests assert read budgets
    get reads() {
      return docReads + queryReads
    },
    // Keyed document gets only (ref.get + getAll) — one read per document fetched
    get docReads() {
      return docReads
    },
    // Collection query gets only — a scan counts 1 whatever the number of docs returned,
    // so asserting queryReads === 0 is the proof that a path never scans a collection
    get queryReads() {
      return queryReads
    },
    get queriedDocs() {
      return queriedDocs
    },
    failCommitsWith: (error: Error) => {
      commitError = error
    },
    failNextQueryWith: (error: Error) => {
      queryError = error
    },
  }
}

export type FakeFirestore = ReturnType<typeof createFakeFirestore>

const holder = { current: createFakeFirestore() }

export const resetFakeFirestore = () => {
  holder.current = createFakeFirestore()
  startFakeRequest()
  return holder.current
}

/** Give the next calls a fresh, stable request context so memoizedPerRequest()
 *  caches within it (mirroring one HTTP request). Each test starts one; a test
 *  that spans two requests — a screen read, then a mutation — starts the second. */
export const startFakeRequest = () => {
  const context: Record<string, unknown> = {}
  ;(globalThis as unknown as { useEvent: () => unknown }).useEvent = () => ({ context })
}

export const fakeDb = () => holder.current.db
