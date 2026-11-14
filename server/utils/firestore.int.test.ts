import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const {
  compositeId,
  deleteAllOwnedBy,
  findDocuments,
  findDocumentsPerRequest,
  readDocuments,
  setInBatches,
} = await import('~/utils/firestore')

type Note = { userId: string; text?: string }

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const notes = () =>
  fakeDb().collection('notes') as unknown as FirebaseFirestore.CollectionReference<Note>

describe('compositeId', () => {
  test('joins the parts with a tilde, in their order', () => {
    expect(compositeId('user-1', '2026-11')).toBe('user-1~2026-11')
    expect(compositeId('user-1', 'dune--frank-herbert')).toBe('user-1~dune--frank-herbert')
  })
})

describe('readDocuments', () => {
  test('answers each id in its order, undefined where nothing is stored', async () => {
    fake.seed('notes', 'b', { userId: 'r', text: 'B' })

    expect(await readDocuments(notes(), ['a', 'b'])).toEqual([
      undefined,
      { userId: 'r', text: 'B' },
    ])
    expect(fake.docReads).toBe(2)
  })

  test('reads nothing for no id', async () => {
    expect(await readDocuments(notes(), [])).toEqual([])
    expect(fake.docReads).toBe(0)
  })
})

describe('findDocuments', () => {
  test('asks each id once and leaves the absent out', async () => {
    fake.seed('notes', 'a', { userId: 'r', text: 'A' })
    fake.seed('notes', 'c', { userId: 'r', text: 'C' })

    const found = await findDocuments(notes(), ['c', 'a', 'c', 'missing'])

    expect(found.map((note) => note.text)).toEqual(['C', 'A'])
    expect(fake.docReads).toBe(3)
  })
})

describe('findDocumentsPerRequest', () => {
  test('reads a document once per request, whoever asks it', async () => {
    startFakeRequest()
    fake.seed('notes', 'a', { userId: 'r', text: 'A' })

    await findDocumentsPerRequest(notes(), ['a', 'b'], (id) => `notes:${id}`)
    const again = await findDocumentsPerRequest(notes(), ['b', 'a'], (id) => `notes:${id}`)

    expect(again.map((note) => note.text)).toEqual(['A'])
    expect(fake.docReads).toBe(2)
  })
})

describe('setInBatches', () => {
  test('writes every document, a few hundred to a batch, without its absent fields', async () => {
    const writes = Array.from({ length: 450 }, (_, index) => ({
      ref: notes().doc(`n${index}`),
      data: { userId: 'r', text: undefined },
    }))

    await setInBatches(writes)

    expect(fake.snapshot('notes').size).toBe(450)
    expect(fake.data('notes', 'n449')).toEqual({ userId: 'r' })
    expect(fake.batches.map((batch) => batch.ops.length)).toEqual([400, 50])
  })
})

describe('deleteAllOwnedBy', () => {
  test('deletes the user’s documents and the ones named beside, never the neighbour’s', async () => {
    fake.seed('notes', 'mine', { userId: 'r' })
    fake.seed('notes', 'theirs', { userId: 'other' })
    fake.seed('balances', 'r', { userId: 'r' })

    await deleteAllOwnedBy(notes(), 'r', [fakeDb().collection('balances').doc('r')])

    expect([...fake.snapshot('notes').keys()]).toEqual(['theirs'])
    expect(fake.snapshot('balances').size).toBe(0)
  })
})
