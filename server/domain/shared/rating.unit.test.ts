import { describe, expect, test } from 'bun:test'
import { StarRating } from '~/domain/shared/primitives'
import { favoriteAfterRating, HEART_RATING } from '~/domain/shared/rating'

describe('a heart is five stars', () => {
  test('stands for the top of the scale', () => {
    expect(HEART_RATING).toBe(StarRating(5))
  })

  test('survives five stars', () => {
    expect(favoriteAfterRating(true, StarRating(5))).toBe(true)
  })

  test('goes with anything less', () => {
    expect(favoriteAfterRating(true, StarRating(4))).toBeUndefined()
    expect(favoriteAfterRating(true, undefined)).toBeUndefined()
  })

  test('is never granted by five stars given by hand', () => {
    expect(favoriteAfterRating(undefined, StarRating(5))).toBeUndefined()
    expect(favoriteAfterRating(false, StarRating(5))).toBeUndefined()
  })
})
