import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { StarRating } from '~/domain/book/primitives'
import { SeriesId } from '~/domain/series/primitives'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { SeriesOpinionCommand } = await import('~/domain/series-opinion/command')
const { SeriesOpinionQuery } = await import('~/domain/series-opinion/query')

const reader = 'reader-1' as UserId
const dune = SeriesId('dune--frank-herbert')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('what a reader makes of a saga', () => {
  test('keeps a rating that is not the average of any volume', async () => {
    await SeriesOpinionCommand.rate(reader, dune, StarRating(4))

    expect(await SeriesOpinionQuery.of(reader, dune)).toMatchObject({ rating: StarRating(4) })
  })

  // The two are independent on purpose: a five-star saga one never wants to open
  // again and a three-star one kept for what it meant are both real.
  test('holds a heart and a rating apart', async () => {
    await SeriesOpinionCommand.rate(reader, dune, StarRating(2))
    await SeriesOpinionCommand.setFavorite(reader, dune, true)

    expect(await SeriesOpinionQuery.of(reader, dune)).toMatchObject({
      rating: StarRating(2),
      favorite: true,
    })
  })

  test('taking the rating back leaves the heart', async () => {
    await SeriesOpinionCommand.setFavorite(reader, dune, true)
    await SeriesOpinionCommand.rate(reader, dune, StarRating(5))
    await SeriesOpinionCommand.rate(reader, dune, undefined)

    expect(await SeriesOpinionQuery.of(reader, dune)).toMatchObject({ favorite: true })
  })

  // A document saying "no rating, not a favourite" says what an absent document
  // already says, and would bill a read for nothing on every tab open.
  test('erases an opinion once nothing is left in it', async () => {
    await SeriesOpinionCommand.setFavorite(reader, dune, true)
    await SeriesOpinionCommand.setFavorite(reader, dune, false)

    expect(await SeriesOpinionQuery.of(reader, dune)).toBeNull()
  })

  test("never answers with another reader's opinion", async () => {
    await SeriesOpinionCommand.rate('reader-2' as UserId, dune, StarRating(1))

    expect(await SeriesOpinionQuery.of(reader, dune)).toBeNull()
  })

  // The series tab reads every opinion, then the saga screen reads one of them.
  // Memoizing the scan is what keeps that at a single billed query.
  test('resolves one saga out of a scan the tab already paid for', async () => {
    await SeriesOpinionCommand.rate(reader, dune, StarRating(3))
    const before = fake.queryReads

    await SeriesOpinionQuery.all(reader)
    await SeriesOpinionQuery.of(reader, dune)

    expect(fake.queryReads - before).toBe(1)
    expect(fake.docReads).toBe(0)
  })
})
