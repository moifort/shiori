import { describe, expect, test } from 'bun:test'
import { editionUnfollowed, followingAfter } from '~/domain/series-opinion/business-rules'

describe('editionUnfollowed', () => {
  test('follows every edition of a saga nobody set aside', () => {
    expect(editionUnfollowed(undefined, 'fr')).toBe(false)
    expect(editionUnfollowed({}, undefined)).toBe(false)
  })

  test('sets aside only the edition named', () => {
    const opinion = { unfollowedLanguages: ['en' as const] }
    expect(editionUnfollowed(opinion, 'en')).toBe(true)
    expect(editionUnfollowed(opinion, 'fr')).toBe(false)
    expect(editionUnfollowed(opinion, undefined)).toBe(false)
  })

  test('a saga set aside as a whole sets aside every edition', () => {
    expect(editionUnfollowed({ unfollowed: true }, 'fr')).toBe(true)
    expect(editionUnfollowed({ unfollowed: true }, undefined)).toBe(true)
  })
})

describe('followingAfter', () => {
  test('sets aside one edition, then follows it again', () => {
    const aside = followingAfter({}, false, 'en', ['fr', 'en'])
    expect(aside).toEqual({ unfollowed: undefined, unfollowedLanguages: ['en'] })
    expect(followingAfter(aside, true, 'en', ['fr', 'en'])).toEqual({
      unfollowed: undefined,
      unfollowedLanguages: undefined,
    })
  })

  test('without an edition, sets aside or follows the whole saga', () => {
    expect(followingAfter({ unfollowedLanguages: ['en'] }, false, undefined, [])).toEqual({
      unfollowed: true,
      unfollowedLanguages: undefined,
    })
    expect(followingAfter({ unfollowed: true }, true, undefined, [])).toEqual({
      unfollowed: undefined,
      unfollowedLanguages: undefined,
    })
  })

  // Following one edition of a saga set aside as a whole leaves the others
  // where the reader put them.
  test('following one edition of a saga set aside keeps the other editions aside', () => {
    expect(followingAfter({ unfollowed: true }, true, 'fr', ['fr', 'en', 'ja'])).toEqual({
      unfollowed: undefined,
      unfollowedLanguages: ['en', 'ja'],
    })
  })
})
