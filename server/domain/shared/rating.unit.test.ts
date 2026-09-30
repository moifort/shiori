import { describe, expect, test } from 'bun:test'
import { StarRating } from '~/domain/shared/primitives'
import {
  favoriteAfterRating,
  HEART_RATING,
  lovedFirst,
  lovedRankOf,
  ratingUnderHeart,
} from '~/domain/shared/rating'

describe('a heart sits on three stars or more', () => {
  test('gives the top of the scale to what holds too few stars', () => {
    expect(HEART_RATING).toBe(StarRating(5))
    expect(ratingUnderHeart(undefined)).toBe(StarRating(5))
    expect(ratingUnderHeart(StarRating(2))).toBe(StarRating(5))
  })

  test("keeps the reader's own stars when they can hold it", () => {
    expect(ratingUnderHeart(StarRating(3))).toBe(StarRating(3))
    expect(ratingUnderHeart(StarRating(4))).toBe(StarRating(4))
  })

  test('survives three, four and five stars', () => {
    expect(favoriteAfterRating(true, StarRating(3))).toBe(true)
    expect(favoriteAfterRating(true, StarRating(4))).toBe(true)
    expect(favoriteAfterRating(true, StarRating(5))).toBe(true)
  })

  test('goes with fewer, or with no rating', () => {
    expect(favoriteAfterRating(true, StarRating(2))).toBeUndefined()
    expect(favoriteAfterRating(true, undefined)).toBeUndefined()
  })

  test('is never granted by five stars given by hand', () => {
    expect(favoriteAfterRating(undefined, StarRating(5))).toBeUndefined()
    expect(favoriteAfterRating(false, StarRating(5))).toBeUndefined()
  })
})

describe('the favourites order', () => {
  test("puts the reader's heart first, then a saga's lent heart, then the stars", () => {
    const ranks = [
      lovedRankOf({ favorite: true, rating: StarRating(5) }),
      lovedRankOf({ lentRating: StarRating(5) }),
      lovedRankOf({ rating: StarRating(5) }),
      lovedRankOf({ rating: StarRating(4), lentRating: StarRating(5) }),
      lovedRankOf({ lentRating: StarRating(3) }),
      lovedRankOf({ rating: StarRating(1) }),
    ]
    expect(ranks).toEqual([...ranks].sort((left = 0, right = 0) => left - right))
    expect(new Set(ranks).size).toBe(ranks.length)
  })

  test('leaves out what was never judged', () => {
    expect(lovedRankOf({})).toBeUndefined()
    expect(lovedFirst([{}, { rating: StarRating(2) }], lovedRankOf, () => 0)).toEqual([
      { rating: StarRating(2) },
    ])
  })

  test('orders one rank by the tie given', () => {
    const rows = [
      { name: 'b', rating: StarRating(4) },
      { name: 'a', rating: StarRating(4) },
    ]
    const ordered = lovedFirst(rows, lovedRankOf, (left, right) =>
      left.name.localeCompare(right.name),
    )
    expect(ordered.map((row) => row.name)).toEqual(['a', 'b'])
  })
})
