import { describe, expect, test } from 'bun:test'
import { answerFrom, answerTextOf } from '~/domain/scan/claude-search'

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

describe('an answer cut short by the output ceiling', () => {
  test('names the ceiling rather than the JSON it left unfinished', () => {
    // 2026-10-21: three author lookups stopped at max_tokens, and the error
    // read "Unexpected end of JSON input" or "returned no text".
    expect(() =>
      answerFrom(
        [
          { type: 'server_tool_use' },
          { type: 'web_search_tool_result' },
          { type: 'text', text: '{"works":[' },
        ],
        'max_tokens',
        'discovery-author-releases',
      ),
    ).toThrow(/discovery-author-releases: Claude ran out of output tokens/)
  })

  test('says so even when nothing was written after the last search', () => {
    expect(() =>
      answerFrom(
        [{ type: 'server_tool_use' }, { type: 'web_search_tool_result' }],
        'max_tokens',
        'x',
      ),
    ).toThrow(/ran out of output tokens/)
  })

  test('an answer that ended on its own without text is reported as such', () => {
    expect(() => answerFrom([{ type: 'text', text: '' }], 'end_turn', 'x')).toThrow(
      /x: Claude returned no text/,
    )
  })

  test('a complete answer is handed back as text', () => {
    expect(answerFrom([{ type: 'text', text: '{"works":[]}' }], 'end_turn', 'x')).toBe(
      '{"works":[]}',
    )
  })
})
