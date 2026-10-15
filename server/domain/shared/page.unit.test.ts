import { describe, expect, test } from 'bun:test'
import { pageAfter } from './page'

const rows = ['a', 'b', 'c', 'd', 'e']
const cursorOf = (row: string) => row

describe('pageAfter', () => {
  test('starts from the top without a cursor', () => {
    expect(pageAfter(rows, { limit: 2 }, cursorOf)).toEqual({
      items: ['a', 'b'],
      hasMore: true,
      endCursor: 'b',
    })
  })

  test('starts after the row the cursor names', () => {
    expect(pageAfter(rows, { limit: 2, after: 'b' }, cursorOf)).toEqual({
      items: ['c', 'd'],
      hasMore: true,
      endCursor: 'd',
    })
  })

  test('says when the last page is reached', () => {
    expect(pageAfter(rows, { limit: 2, after: 'd' }, cursorOf)).toEqual({
      items: ['e'],
      hasMore: false,
      endCursor: 'e',
    })
  })

  test('restarts from the top on a cursor naming a row no longer there', () => {
    expect(pageAfter(rows, { limit: 2, after: 'gone' }, cursorOf).items).toEqual(['a', 'b'])
  })

  test('keeps the offset for the builds that still send one', () => {
    expect(pageAfter(rows, { limit: 2, offset: 3 }, cursorOf).items).toEqual(['d', 'e'])
  })

  test('the cursor wins over an offset', () => {
    expect(pageAfter(rows, { limit: 1, after: 'a', offset: 3 }, cursorOf).items).toEqual(['b'])
  })

  test('an empty page has no cursor', () => {
    expect(pageAfter([], { limit: 2 }, cursorOf)).toEqual({
      items: [],
      hasMore: false,
      endCursor: null,
    })
  })
})
