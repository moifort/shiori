import type { AiStepUsage } from '~/domain/scan/types'
import { config } from '~/system/config'
import { createLogger } from '~/system/logger'

const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'

const logger = createLogger('scan')

/** What Gemini reports a call cost. Thinking tokens bill at the output rate and
 *  are the largest line on a scan, which is why they are read separately rather
 *  than trusted to be inside `candidatesTokenCount`. */
type GeminiUsage = {
  promptTokenCount?: number
  candidatesTokenCount?: number
  thoughtsTokenCount?: number
}

type GeminiResponse = {
  candidates?: { content?: { parts?: { text?: string }[] } }[]
  usageMetadata?: GeminiUsage
}

type Part = { text: string } | { inline_data: { mime_type: string; data: string } }

/** One call to the model, returning the decoded JSON and what it consumed.
 *
 *  `usage` is captured on every step so the allowance and the price can be
 *  recalibrated against measured tokens rather than an estimate — Vinarium's
 *  first costing was four times under for exactly the want of this.
 */
export const generate = async <T>(options: {
  step: string
  parts: Part[]
  responseSchema: unknown
  /** Grounding is what makes enrichment and cataloguing worth their cost; the
   *  vision step must NOT use it, since the answer is in the image. */
  grounded?: boolean
}): Promise<{ value: T; usage?: AiStepUsage }> => {
  const { googleApiKey } = config()

  const response = await $fetch<GeminiResponse>(`${GEMINI_API_URL}?key=${googleApiKey}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: {
      contents: [{ parts: options.parts }],
      ...(options.grounded ? { tools: [{ google_search: {} }] } : {}),
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: options.responseSchema,
      },
    },
  })

  const text = response.candidates?.[0]?.content?.parts?.map((part) => part.text ?? '').join('')
  if (!text) throw new Error(`${options.step}: Gemini returned no content`)

  return {
    value: JSON.parse(text) as T,
    usage: capturedUsage(options.step, response.usageMetadata),
  }
}

const capturedUsage = (step: string, usage: GeminiUsage | undefined): AiStepUsage | undefined => {
  if (!usage) return undefined
  logger.info(
    `${step}: ${usage.promptTokenCount ?? 0} in, ${usage.candidatesTokenCount ?? 0} out, ${usage.thoughtsTokenCount ?? 0} thinking`,
  )
  return {
    promptTokens: usage.promptTokenCount ?? 0,
    outputTokens: usage.candidatesTokenCount ?? 0,
    thinkingTokens: usage.thoughtsTokenCount ?? 0,
  }
}
