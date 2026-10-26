import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { StarRating } from '~/domain/book/primitives'
import type { ReadingStatus } from '~/domain/book/types'
import { SagaKey, SeriesName, VolumeNumber } from '~/domain/series/primitives'
import { BookTitle } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { BookCommand } = await import('~/domain/book/command')
const { SeriesOpinionCommand } = await import('~/domain/series-opinion/command')
const { SeriesOpinionUseCase } = await import('~/domain/series-opinion/use-case')

const reader = 'reader-1' as UserId
const dune = SagaKey('dune--frank-herbert')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const volume = (number: number, status: ReadingStatus, saga = dune) =>
  BookCommand.add(reader, {
    title: BookTitle(`Dune ${number}`),
    status,
    series: {
      saga,
      name: SeriesName('Dune'),
      volume: VolumeNumber(number),
      kind: 'main',
    },
  })

const ratingOf = (bookId: string) => fake.data('books', bookId)?.rating

// The heart on a saga is the reader's verdict on every volume they finished
// without judging it on its own.
describe('hearting a saga', () => {
  test('gives its stars to the volumes read and left unrated', async () => {
    const first = await volume(1, 'read')
    const second = await volume(2, 'read')

    await SeriesOpinionUseCase.setFavorite(reader, dune, true)

    expect(ratingOf(first.id)).toBe(StarRating(5))
    expect(ratingOf(second.id)).toBe(StarRating(5))
  })

  test('gives the stars the saga keeps under its heart', async () => {
    const first = await volume(1, 'read')
    await SeriesOpinionCommand.rate(reader, dune, StarRating(4))

    await SeriesOpinionUseCase.setFavorite(reader, dune, true)

    expect(ratingOf(first.id)).toBe(StarRating(4))
  })

  test('leaves a volume the reader rated on its own', async () => {
    const first = await volume(1, 'read')
    await BookCommand.rate(reader, first.id, StarRating(3))

    await SeriesOpinionUseCase.setFavorite(reader, dune, true)

    expect(ratingOf(first.id)).toBe(StarRating(3))
  })

  // Stars mark a book read: lent to the pile, they would say the reader
  // finished what they have not opened.
  test('leaves the volumes not read yet unrated, on their shelf', async () => {
    const next = await volume(3, 'to-read')
    const current = await volume(2, 'reading')

    await SeriesOpinionUseCase.setFavorite(reader, dune, true)

    expect(ratingOf(next.id)).toBeUndefined()
    expect(fake.data('books', next.id)?.status).toBe('to-read')
    expect(ratingOf(current.id)).toBeUndefined()
  })

  test('leaves the volumes of another saga', async () => {
    const other = await volume(1, 'read', SagaKey('hyperion--dan-simmons'))

    await SeriesOpinionUseCase.setFavorite(reader, dune, true)

    expect(ratingOf(other.id)).toBeUndefined()
  })

  test('taking the heart back leaves the stars it gave', async () => {
    const first = await volume(1, 'read')
    await SeriesOpinionUseCase.setFavorite(reader, dune, true)

    await SeriesOpinionUseCase.setFavorite(reader, dune, false)

    expect(ratingOf(first.id)).toBe(StarRating(5))
  })

  test('lands the volumes, the heart and the analytics flag in one batch', async () => {
    await volume(1, 'read')
    await volume(2, 'read')

    await SeriesOpinionUseCase.setFavorite(reader, dune, true)

    expect(fake.batches.at(-1)?.ops.map((op) => op.ref.collectionPath)).toEqual([
      'series-opinions',
      'books',
      'books',
      'analytics',
    ])
  })
})
