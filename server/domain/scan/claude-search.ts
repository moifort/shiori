import { answerOf, answerShape } from '~/domain/scan/json-answer'
import type { AiStepUsage } from '~/domain/scan/types'
import { config } from '~/system/config'
import { createLogger } from '~/system/logger'

/** The model a grounded step runs on once Gemini's free searches are spent:
 *  the cheapest Claude, since the web search does the knowing. */
export const CLAUDE_SEARCH_MODEL = 'claude-haiku-5-5'

const API_URL = 'https://api.anthropic.com/v1/messages'

/** The searches one call may run. Gemini, which cannot be told, ran six on
 *  average on 2026-10-19 (421 billed for 67 calls); each costs a cent here,
 *  and its results are read as input tokens besides. */
const MAX_SEARCHES = 2

/** The answer is a few hundred tokens of JSON, but what Claude writes between
 *  its searches counts too, and an author's release list runs long: on
 *  2026-10-21 three author lookups out of sixteen stopped at 4,000 and came
 *  back without their answer. Output is the cheap side of a Haiku call. */
const MAX_TOKENS = 16_000

/** A search turn can run long; past this the step fails as Gemini's would. */
const TIMEOUT_MS = 90_000

/** A long search turn comes back paused, to be sent again as it stands. */
const MAX_CONTINUATIONS = 2

const logger = createLogger('scan')

type Block = { type: string; text?: string }

type MessagesResponse = {
  content?: Block[]
  stop_reason?: string
  usage?: {
    input_tokens?: number
    output_tokens?: number
    server_tool_use?: { web_search_requests?: number }
  }
}

type SearchOptions = {
  step: string
  prompt: string
  responseSchema: unknown
  /** The model, for a bench to compare another; the default otherwise. */
  model?: string
}

/** A grounded step answered by Claude with its web search tool: the same
 *  prompt Gemini is given, the same JSON read out of free text.
 *
 *  Unlike Gemini, the answer says exactly how many searches were billed, and
 *  the number is capped. Throws on a failed request, as Gemini's `generate`
 *  does: the caller decides what a failure means. */
export const searchedWithClaude = async <T>({
  step,
  prompt,
  responseSchema,
  model = CLAUDE_SEARCH_MODEL,
}: SearchOptions): Promise<{ value: T; usage: AiStepUsage }> => {
  const key = config().anthropicApiKey
  if (!key) throw new Error('Anthropic API key is not configured')
  const messages: { role: 'user' | 'assistant'; content: string | Block[] }[] = [
    { role: 'user', content: `${prompt}\n\n${answerShape(responseSchema)}` },
  ]
  const usage: AiStepUsage = { promptTokens: 0, outputTokens: 0, thinkingTokens: 0, searches: 0 }
  let content: Block[] = []
  let stopReason: string | undefined
  for (let turn = 0; turn <= MAX_CONTINUATIONS; turn += 1) {
    const body = await asked(key, model, messages)
    usage.promptTokens += body.usage?.input_tokens ?? 0
    usage.outputTokens += body.usage?.output_tokens ?? 0
    usage.searches += body.usage?.server_tool_use?.web_search_requests ?? 0
    content = [...content, ...(body.content ?? [])]
    stopReason = body.stop_reason
    if (stopReason !== 'pause_turn') break
    messages.push({ role: 'assistant', content: body.content ?? [] })
  }
  logger.info('claude search usage', {
    step,
    model,
    inputTokens: usage.promptTokens,
    outputTokens: usage.outputTokens,
    searches: usage.searches,
    stopReason,
  })
  const text = answerFrom(content, stopReason, step)
  try {
    return { value: answerOf(text) as T, usage }
  } catch (error) {
    throw new Error(`${step}: ${(error as Error).message} — ${text.slice(0, 2000)}`)
  }
}

/** The answer's text, or why there is none: a turn stopped at the output
 *  ceiling left its JSON unfinished, and the error says so rather than
 *  reporting the broken JSON, so the ceiling shows as itself in Sentry. */
export const answerFrom = (
  content: readonly Block[],
  stopReason: string | undefined,
  step: string,
): string => {
  const text = answerTextOf(content)
  if (stopReason === 'max_tokens')
    throw new Error(`${step}: Claude ran out of output tokens — ${text.slice(0, 200)}`)
  if (!text) throw new Error(`${step}: Claude returned no text`)
  return text
}

/** The text written after the last search: what Claude says before searching
 *  ("I'll look this up") is not the answer. */
export const answerTextOf = (content: readonly Block[]): string => {
  const lastResult = content.findLastIndex((block) => block.type === 'web_search_tool_result')
  return content
    .slice(lastResult + 1)
    .filter((block) => block.type === 'text')
    .map((block) => block.text ?? '')
    .join('')
}

const asked = async (
  key: string,
  model: string,
  messages: { role: 'user' | 'assistant'; content: string | Block[] }[],
): Promise<MessagesResponse> => {
  const response = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      max_tokens: MAX_TOKENS,
      messages,
      tools: [{ type: 'web_search_20250305', name: 'web_search', max_uses: MAX_SEARCHES }],
    }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  })
  if (!response.ok)
    throw new Error(`Claude answered ${response.status}: ${(await response.text()).slice(0, 500)}`)
  return (await response.json()) as MessagesResponse
}
