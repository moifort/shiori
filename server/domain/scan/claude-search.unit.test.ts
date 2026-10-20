import { describe, expect, test } from 'bun:test'
import { answerTextOf } from '~/domain/scan/claude-search'

describe("reading Claude's answer after its searches", () => {
  test('keeps the text written after the last search, not what came before', () => {
    expect(
      answerTextOf([
        { type: 'text', text: 'Je cherche cette édition.' },
        { type: 'server_tool_use' },
        { type: 'web_search_tool_result' },
        { type: 'text', text: 'Encore une.' },
        { type: 'server_tool_use' },
        { type: 'web_search_tool_result' },
        { type: 'text', text: '{"isbn13":' },
        { type: 'text', text: '"9780593135204"}' },
      ]),
    ).toBe('{"isbn13":"9780593135204"}')
  })

  test('keeps the whole text of an answer that searched nothing', () => {
    expect(answerTextOf([{ type: 'text', text: '{"volumes":[]}' }])).toBe('{"volumes":[]}')
  })
})
