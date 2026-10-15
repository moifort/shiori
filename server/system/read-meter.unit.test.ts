import { afterEach, describe, expect, test } from 'bun:test'
import { meterFirestoreReads, startReadMeter } from './read-meter'

// Stand-ins for the Firestore client classes: the meter wraps their prototypes
// exactly as it wraps the real ones.
class DocumentReference {
  constructor(readonly path: string) {}
}
class Query {
  constructor(readonly size: number) {}
  async get() {
    return { size: this.size }
  }
}
class AggregateQuery {
  async get() {
    return { data: () => ({ count: 12 }) }
  }
}
class Firestore {
  async getAll(...refs: unknown[]) {
    return refs
  }
}
class Transaction {
  async get(target: unknown) {
    return target instanceof Query ? { size: target.size } : { exists: true }
  }
  async getAll(...refs: unknown[]) {
    return refs
  }
}

meterFirestoreReads({ Firestore, Query, AggregateQuery, Transaction, DocumentReference })
// A second call wraps nothing again, or every read would count twice.
meterFirestoreReads({ Firestore, Query, AggregateQuery, Transaction, DocumentReference })

// The meter reads the current H3 event via the auto-imported useEvent().
const inRequest = (context: Record<string, unknown>) => {
  ;(globalThis as unknown as { useEvent: () => unknown }).useEvent = () => ({ context })
}

describe('meterFirestoreReads', () => {
  afterEach(() => {
    delete (globalThis as unknown as { useEvent?: unknown }).useEvent
  })

  test('counts documents read by reference and the documents queries return', async () => {
    const context = {}
    const meter = startReadMeter(context)
    inRequest(context)

    await new Firestore().getAll(new DocumentReference('a/1'), new DocumentReference('a/2'), {
      fieldMask: ['title'],
    })
    await new Query(7).get()
    await new Query(0).get()
    await new AggregateQuery().get()

    expect(meter).toEqual({ docReads: 2, queryReads: 3, queryDocs: 7 })
  })

  test('counts a transaction reading a document, a query and a batch', async () => {
    const context = {}
    const meter = startReadMeter(context)
    inRequest(context)
    const tx = new Transaction()

    await tx.get(new DocumentReference('a/1'))
    await tx.get(new Query(4))
    await tx.getAll(new DocumentReference('a/2'), new DocumentReference('a/3'))

    expect(meter).toEqual({ docReads: 3, queryReads: 1, queryDocs: 4 })
  })

  test('keeps concurrent requests apart', async () => {
    const first = {}
    const second = {}
    const firstMeter = startReadMeter(first)
    const secondMeter = startReadMeter(second)

    // Each read is attributed to the request it started in, even when the two
    // interleave and finish in the other order.
    inRequest(first)
    const slow = new Query(5).get()
    inRequest(second)
    const fast = new Firestore().getAll(new DocumentReference('a/1'))
    await Promise.all([fast, slow])

    expect(firstMeter).toEqual({ docReads: 0, queryReads: 1, queryDocs: 5 })
    expect(secondMeter).toEqual({ docReads: 1, queryReads: 0, queryDocs: 0 })
  })

  test('reads outside a request still answer, counted nowhere', async () => {
    expect(await new Query(3).get()).toEqual({ size: 3 })
  })
})
