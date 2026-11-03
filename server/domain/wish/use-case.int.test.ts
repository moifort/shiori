import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  resetFakeFirestore,
  startFakeRequest,
} from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { WishUseCase } = await import('~/domain/wish/use-case')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const bob = 'bob' as UserId
let fake: FakeFirestore

beforeEach(() => {
  fake = resetFakeFirestore()
})

const wish = (title: string, now: Date) =>
  WishUseCase.wish(
    bob,
    { title: BookTitle(title), authors: [AuthorName('Susanna Clarke')], format: 'book' },
    { kind: 'discovery' },
    now,
  )

describe('the wishlist', () => {
  test('lists the latest wish first', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    await wish('Jonathan Strange', new Date('2026-11-02'))

    const titles = (await WishUseCase.wishes(bob)).map((wish) => wish.title)

    expect(titles).toEqual([BookTitle('Jonathan Strange'), BookTitle('Piranesi')])
  })

  test('reads the wishes and the library in one query each', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await WishUseCase.wishes(bob)

    expect(fake.queryReads - before.queries).toBe(2)
    expect(fake.docReads - before.docs).toBe(0)
  })
})
