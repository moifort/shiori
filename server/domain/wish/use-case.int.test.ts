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
const { AuthorName, BookTitle, PersonName } = await import('~/domain/shared/primitives')

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

    const titles = (await WishUseCase.wishes(bob, 'fr')).map((wish) => wish.title)

    expect(titles).toEqual([BookTitle('Jonathan Strange'), BookTitle('Piranesi')])
  })

  test('reads the wishes and the library in one query each, and one release per wish', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await WishUseCase.wishes(bob, 'fr')

    expect(fake.queryReads - before.queries).toBe(2)
    expect(fake.docReads - before.docs).toBe(1)
  })
})

describe('a story the library comes to hold', () => {
  const clarke = [AuthorName('Susanna Clarke')]

  test('deletes its wish when the book arrives, for good', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    await wish('Jonathan Strange', new Date('2026-11-02'))

    const book = await BookCommand.add(bob, { title: BookTitle('Piranesi'), authors: clarke })
    await BookCommand.remove(bob, book.id)

    const titles = (await WishUseCase.wishes(bob, 'fr')).map((wish) => wish.title)
    expect(titles).toEqual([BookTitle('Jonathan Strange')])
  })

  test('deletes its wish when an edit names the book after it', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    const book = await BookCommand.add(bob, { title: BookTitle('Piranessi'), authors: clarke })
    expect(await WishUseCase.wishes(bob, 'fr')).toHaveLength(1)

    await BookCommand.edit(bob, book.id, { title: BookTitle('Piranesi') })

    expect(fake.snapshot('wishes').size).toBe(0)
  })

  test('reads the wishes once and deletes only the one held', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await WishCommand.forgetHeld(bob, [{ title: BookTitle('Piranesi'), authors: clarke }])

    expect(fake.queryReads - before.queries).toBe(1)
    expect(fake.docReads - before.docs).toBe(0)
    expect(fake.snapshot('wishes').size).toBe(0)
  })

  // A sync shelves book after book: the wishes it read stay read.
  test('writes nothing for a story never wished for, and keeps the list it read', async () => {
    await wish('Piranesi', new Date('2026-11-01'))
    startFakeRequest()
    await WishCommand.forgetHeld(bob, [{ title: BookTitle('Dune'), authors: clarke }])
    const before = fake.queryReads

    await WishCommand.forgetHeld(bob, [{ title: BookTitle('Hyperion'), authors: clarke }])

    expect(fake.queryReads - before).toBe(0)
    expect(fake.snapshot('wishes').size).toBe(1)
  })

  test('a book wished for at a friend’s arrives recommended by that friend', async () => {
    await WishUseCase.wish(
      bob,
      { title: BookTitle('Piranesi'), authors: clarke, format: 'book' },
      { kind: 'friend', friendId: 'guillaume' as UserId, label: 'Guillaume' },
    )

    const book = await BookCommand.add(bob, {
      title: BookTitle('Piranesi'),
      authors: clarke,
      format: 'audiobook',
    })

    expect(book.recommendation).toEqual({ recommenderName: PersonName('Guillaume') })
    expect(fake.snapshot('wishes').size).toBe(0)
  })

  test('a book wished for from a discovery arrives with no recommendation', async () => {
    await wish('Piranesi', new Date('2026-11-01'))

    const book = await BookCommand.add(bob, { title: BookTitle('Piranesi'), authors: clarke })

    expect(book.recommendation).toBeUndefined()
  })

  test('the reader’s own word on who recommended it is kept', async () => {
    await WishUseCase.wish(
      bob,
      { title: BookTitle('Piranesi'), authors: clarke, format: 'book' },
      { kind: 'friend', friendId: 'guillaume' as UserId, label: 'Guillaume' },
    )

    const book = await BookCommand.add(bob, {
      title: BookTitle('Piranesi'),
      authors: clarke,
      recommendation: { recommenderName: PersonName('Marie') },
    })

    expect(book.recommendation).toEqual({ recommenderName: PersonName('Marie') })
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

    expect(await WishUseCase.wishes(bob, 'fr')).toEqual([])
    expect(fake.snapshot('wishes').size).toBe(1)
  })
})

describe('a wish described for its page', () => {
  test('is not found among another reader’s wishes', async () => {
    const own = await wish('Piranesi', new Date('2026-11-01'))
    if (typeof own === 'string') throw new Error('expected a wish')

    expect(await WishUseCase.describe('alice' as UserId, own.id, 'fr')).toBe('not-found')
  })
})
