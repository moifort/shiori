import { afterEach, describe, expect, test } from 'bun:test'
import { meterFirestoreWrites, startWriteMeter, writesOf } from './write-meter'

// A stand-in for the Firestore client's `WriteBatch`: the meter wraps its
// prototype exactly as it wraps the real one, which returns the batch to chain.
class WriteBatch {
  create() {
    return this
  }
  set() {
    return this
  }
  update() {
    return this
  }
  delete() {
    return this
  }
}

meterFirestoreWrites({ WriteBatch })
// A second call wraps nothing again, or every write would count twice.
meterFirestoreWrites({ WriteBatch })

// The meter reads the current H3 event via the auto-imported useEvent().
const inRequest = (context: Record<string, unknown>) => {
  ;(globalThis as unknown as { useEvent: () => unknown }).useEvent = () => ({ context })
}

describe('meterFirestoreWrites', () => {
  afterEach(() => {
    delete (globalThis as unknown as { useEvent?: unknown }).useEvent
  })

  test('counts each kind of write, and still chains', () => {
    const context = {}
    const meter = startWriteMeter(context)
    inRequest(context)
    const batch = new WriteBatch()

    expect(batch.create().set().set().update().delete()).toBe(batch)
    expect(meter).toEqual({ creates: 1, sets: 2, updates: 1, deletes: 1 })
    expect(writesOf(meter)).toBe(5)
  })

  test('keeps concurrent requests apart', () => {
    const first = {}
    const second = {}
    const firstMeter = startWriteMeter(first)
    const secondMeter = startWriteMeter(second)

    inRequest(first)
    new WriteBatch().set()
    inRequest(second)
    new WriteBatch().update().update()

    expect(writesOf(firstMeter)).toBe(1)
    expect(secondMeter.updates).toBe(2)
  })

  test('writes outside a request still go through, counted nowhere', () => {
    const batch = new WriteBatch()
    expect(batch.set()).toBe(batch)
  })
})
