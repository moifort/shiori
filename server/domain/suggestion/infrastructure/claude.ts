import { config } from '~/system/config'
import { createLogger } from '~/system/logger'

/** The model the month's discoveries are chosen by: the readers' pick of
 *  four, blind, on 2026-10-12 — Haiku, Sonnet, Opus and Gemini 3.1 Pro given
 *  the same library and prompt. Priced in the spec at $3 / $15 per million
 *  tokens in / out. */
const CLAUDE_MODEL = 'claude-sonnet-5-5'

const API_URL = 'https://api.anthropic.com/v1/messages'

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

type MessagesResponse = {
  content?: { type: string; text?: string }[]
  usage?: { input_tokens?: number; output_tokens?: number }
}

/** Whether the month's discoveries can be chosen at all: without a key the
 *  line is absent, and nothing else changes. */
export const isConfigured = () => config().anthropicApiKey !== undefined

/** The model's answer to one prompt, as text. Throws on a failed request: the
 *  caller logs it and keeps the selection it had. */
export const ask = async (prompt: string): Promise<string> => {
  const key = config().anthropicApiKey
  if (!key) throw new Error('Anthropic API key is not configured')
  const response = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: MAX_TOKENS,
      messages: [{ role: 'user', content: prompt }],
    }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  })
  if (!response.ok)
    throw new Error(`Claude answered ${response.status}: ${(await response.text()).slice(0, 500)}`)
  const body = (await response.json()) as MessagesResponse
  logger.info('discoveries generated', {
    model: CLAUDE_MODEL,
    inputTokens: body.usage?.input_tokens,
    outputTokens: body.usage?.output_tokens,
  })
  return (body.content ?? []).map((part) => part.text ?? '').join('')
}
