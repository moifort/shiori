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
const { BookCommand } = await import('~/domain/book/command')
const { WishCommand } = await import('~/domain/wish/command')
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

describe('a story the library comes to hold', () => {
  const clarke = [AuthorName('Susanna Clarke')]

  test('deletes its wish when the book arrives, for good', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    await wish('Jonathan Strange', new Date('2026-11-02'))

    const book = await BookCommand.add(bob, { title: BookTitle('Piranesi'), authors: clarke })
    await BookCommand.remove(bob, book.id)

    const titles = (await WishUseCase.wishes(bob)).map((wish) => wish.title)
    expect(titles).toEqual([BookTitle('Jonathan Strange')])
  })

  test('deletes its wish when an edit names the book after it', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    const book = await BookCommand.add(bob, { title: BookTitle('Piranessi'), authors: clarke })
    expect(await WishUseCase.wishes(bob)).toHaveLength(1)

    await BookCommand.edit(bob, book.id, { title: BookTitle('Piranesi') })

    expect(fake.snapshot('wishes').size).toBe(0)
  })

  test('deletes nothing it did not read, and reads nothing to delete', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await WishCommand.forgetHeld(bob, [{ title: BookTitle('Piranesi'), authors: clarke }])

    expect(fake.queryReads - before.queries).toBe(0)
    expect(fake.docReads - before.docs).toBe(0)
    expect(fake.snapshot('wishes').size).toBe(0)
  })

  test('leaves a wish held before the rule out of the list, without deleting it', async () => {
    await BookCommand.add(bob, { title: BookTitle('Piranesi'), authors: clarke })
    fake.seed('wishes', 'bob--piranesi--susanna-clarke', {
      id: 'bob--piranesi--susanna-clarke',
      userId: bob,
      title: 'Piranesi',
      authors: ['Susanna Clarke'],
      format: 'book',
      origin: { kind: 'discovery' },
      wishedAt: new Date('2026-11-01'),
    })

    expect(await WishUseCase.wishes(bob)).toEqual([])
    expect(fake.snapshot('wishes').size).toBe(1)
  })
})
