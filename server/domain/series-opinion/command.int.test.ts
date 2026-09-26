import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { StarRating } from '~/domain/book/primitives'
import { SeriesId, VolumeNumber } from '~/domain/series/primitives'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

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

  // The heart is the top of the scale, as on a book.
  test('giving the heart rates the saga five', async () => {
    await SeriesOpinionCommand.rate(reader, dune, StarRating(2))
    const now = new Date(Date.UTC(2026, 8, 20))
    await SeriesOpinionCommand.setFavorite(reader, dune, true, undefined, now)

    expect(await SeriesOpinionQuery.of(reader, dune)).toMatchObject({
      rating: StarRating(5),
      favorite: true,
      favoritedAt: now,
    })
  })

  // Hearting it again is not news for a friend.
  test('hearting a saga again keeps the date of the first heart', async () => {
    const first = new Date(Date.UTC(2026, 8, 20))
    await SeriesOpinionCommand.setFavorite(reader, dune, true, undefined, first)
    await SeriesOpinionCommand.setFavorite(reader, dune, true, undefined, new Date())

    expect((await SeriesOpinionQuery.of(reader, dune))?.favoritedAt).toEqual(first)
  })

  // Heart and stars gone together leave nothing: the opinion is erased.
  test('taking the heart back takes the stars with it', async () => {
    await SeriesOpinionCommand.setFavorite(reader, dune, true)
    await SeriesOpinionCommand.setFavorite(reader, dune, false)

    expect(await SeriesOpinionQuery.of(reader, dune)).toBeNull()
  })

  test('rating below five takes the heart back', async () => {
    await SeriesOpinionCommand.setFavorite(reader, dune, true)
    await SeriesOpinionCommand.rate(reader, dune, StarRating(4))

    const opinion = await SeriesOpinionQuery.of(reader, dune)
    expect(opinion?.rating).toBe(StarRating(4))
    expect(opinion?.favorite).toBeUndefined()
    expect(opinion?.favoritedAt).toBeUndefined()
  })

  test('taking the rating back takes the heart back', async () => {
    await SeriesOpinionCommand.setFavorite(reader, dune, true)
    await SeriesOpinionCommand.rate(reader, dune, undefined)

    expect(await SeriesOpinionQuery.of(reader, dune)).toBeNull()
  })

  // How many volumes the reader says the saga has, when nobody has catalogued
  // it: theirs alone, never written into the shared catalogue.
  test('keeps a saga the reader stopped following', async () => {
    await SeriesOpinionCommand.setFollowed(reader, dune, false, undefined, [])

    expect(await SeriesOpinionQuery.of(reader, dune)).toMatchObject({ unfollowed: true })
  })

  // Following is what an absent opinion already says.
  test('erases the opinion when following again leaves nothing in it', async () => {
    await SeriesOpinionCommand.setFollowed(reader, dune, false, undefined, [])
    await SeriesOpinionCommand.setFollowed(reader, dune, true, undefined, [])

    expect(await SeriesOpinionQuery.of(reader, dune)).toBeNull()
  })

  test('keeps the number of volumes the reader declared', async () => {
    await SeriesOpinionCommand.declareVolumeCount(reader, dune, VolumeNumber(6))

    expect(await SeriesOpinionQuery.of(reader, dune)).toMatchObject({
      volumeCount: VolumeNumber(6),
    })
  })

  test('a declared count alone keeps the opinion stored', async () => {
    await SeriesOpinionCommand.rate(reader, dune, StarRating(5))
    await SeriesOpinionCommand.declareVolumeCount(reader, dune, VolumeNumber(6))
    await SeriesOpinionCommand.rate(reader, dune, undefined)

    expect(await SeriesOpinionQuery.of(reader, dune)).toMatchObject({
      volumeCount: VolumeNumber(6),
    })
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
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await SeriesOpinionQuery.all(reader)
    await SeriesOpinionQuery.of(reader, dune)

    expect(fake.queryReads - before.queries).toBe(1)
    expect(fake.docReads - before.docs).toBe(0)
  })

  // The saga screen alone: one document, not every opinion of the reader.
  test('reads one saga’s opinion by its document when no scan was paid for', async () => {
    await SeriesOpinionCommand.rate(reader, dune, StarRating(3))
    await SeriesOpinionCommand.rate('reader-2' as UserId, dune, StarRating(5))
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    const opinion = await SeriesOpinionQuery.of(reader, dune)

    expect(opinion).toMatchObject({ userId: reader, rating: StarRating(3) })
    expect(fake.docReads - before.docs).toBe(1)
    expect(fake.queryReads - before.queries).toBe(0)
  })
})

describe('deleting an account', () => {
  test('forgets more opinions than one batch can carry', async () => {
    for (let index = 0; index < 520; index++)
      await SeriesOpinionCommand.rate(reader, SeriesId(`saga-${index}`), StarRating(3))

    await SeriesOpinionCommand.deleteAllForUser(reader)

    expect(await SeriesOpinionQuery.all(reader)).toHaveLength(0)
  })
})
