import { askClaude, isClaudeConfigured, textOf } from '~/system/claude'
import { createLogger } from '~/system/logger'

/** The model the month's discoveries are chosen by: the readers' pick of
 *  four, blind, on 2026-10-12 — Haiku, Sonnet, Opus and Gemini 3.1 Pro given
 *  the same library and prompt. Priced in the spec at $3 / $15 per million
 *  tokens in / out. */
const CLAUDE_MODEL = 'claude-sonnet-5-5'

/** Twenty suggestions with their reasons came to 6,863 tokens on 2026-10-15,
 *  then 10,369 in production the same day; an answer cut short is unreadable
 *  JSON, so the ceiling leaves room — the reasons are now capped at 25 words —
 *  without letting a runaway answer bill without end. */
const MAX_TOKENS = 16_000

/** A generation was measured at 53 s, then 83 s in production, on
 *  2026-10-15; past two minutes and a half the call is abandoned, inside the
 *  function's three. */
const TIMEOUT_MS = 150_000

const logger = createLogger('suggestion')

/** Whether the month's discoveries can be chosen at all: without a key the
 *  line is absent, and nothing else changes. */
export const isConfigured = isClaudeConfigured

/** The model's answer to one prompt, as text. Throws on a failed request: the
 *  caller logs it and keeps the selection it had. */
export const ask = async (prompt: string): Promise<string> => {
  const answer = await askClaude(
    {
      model: CLAUDE_MODEL,
      max_tokens: MAX_TOKENS,
      messages: [{ role: 'user', content: prompt }],
    },
    TIMEOUT_MS,
  )
  logger.info('discoveries generated', {
    model: CLAUDE_MODEL,
    inputTokens: answer.usage?.input_tokens,
    outputTokens: answer.usage?.output_tokens,
  })
  return textOf(answer)
}
