import { describe, expect, test } from 'bun:test'
import { promptsToShow } from '~/domain/user/business-rules'

const nothingSetUp = {
  audibleConnected: false,
  kindleConnected: false,
  hasFriend: false,
  dismissed: [],
}

describe('the prompts the home hero shows', () => {
  test('asks for everything, Audible first, then Kindle, then a friend', () => {
    expect(promptsToShow(nothingSetUp)).toEqual(['audible', 'kindle', 'friends'])
  })

  test('stops asking for what is set up', () => {
    expect(promptsToShow({ ...nothingSetUp, audibleConnected: true, hasFriend: true })).toEqual([
      'kindle',
    ])
  })

  test('stops asking for what the reader turned down', () => {
    expect(promptsToShow({ ...nothingSetUp, dismissed: ['kindle', 'audible'] })).toEqual([
      'friends',
    ])
  })

  test('asks for nothing once all is done', () => {
    expect(
      promptsToShow({
        audibleConnected: true,
        kindleConnected: true,
        hasFriend: true,
        dismissed: [],
      }),
    ).toEqual([])
  })
})
