import { config } from '~/system/config'

/** The Anthropic Messages API, shared by every caller of Claude. Each caller
 *  keeps its own model, token ceiling, timeout and tools: this is the
 *  transport — the endpoint, the key, the headers and what a refusal throws. */
const API_URL = 'https://api.anthropic.com/v1/messages'

export type ClaudeBlock = { type: string; text?: string }

export type ClaudeMessage = { role: 'user' | 'assistant'; content: string | ClaudeBlock[] }

export type ClaudeAnswer = {
  content?: ClaudeBlock[]
  stop_reason?: string
  usage?: {
    input_tokens?: number
    output_tokens?: number
    server_tool_use?: { web_search_requests?: number }
  }
}

/** Whether Claude can be called at all: without a key, every feature that asks
 *  it is absent, and nothing else changes. */
export const isClaudeConfigured = () => config().anthropicApiKey !== undefined

/** One call to the Messages API. Throws without a key, and on any answer that
 *  is not a success, with the start of what Claude said: the caller decides
 *  what a failure means. */
export const askClaude = async (
  request: {
    model: string
    max_tokens: number
    messages: readonly ClaudeMessage[]
    tools?: readonly Record<string, unknown>[]
  },
  timeoutMs: number,
): Promise<ClaudeAnswer> => {
  const key = config().anthropicApiKey
  if (!key) throw new Error('Anthropic API key is not configured')
  const response = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify(request),
    signal: AbortSignal.timeout(timeoutMs),
  })
  if (!response.ok)
    throw new Error(`Claude answered ${response.status}: ${(await response.text()).slice(0, 500)}`)
  return (await response.json()) as ClaudeAnswer
}

/** The text of an answer, every text block joined. */
export const textOf = (answer: ClaudeAnswer): string =>
  (answer.content ?? []).map((part) => part.text ?? '').join('')
