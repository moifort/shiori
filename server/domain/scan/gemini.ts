import type { AiStepUsage } from '~/domain/scan/types'
import { config } from '~/system/config'
import { createLogger } from '~/system/logger'

/** The model every scan step calls.
 *
 *  Not 2.5-flash, which Vinarium still uses: Google stopped serving it to new
 *  projects, and a fresh API key gets a 404 pointing here. Kept as a named
 *  constant because the next retirement will land the same way — the failure is
 *  a 404 on the model path, not a deprecation warning.
 *
 *  Lite rather than 3.6-flash, which this called until the real price list was
 *  read: 3.6-flash bills $0.75/$3.75 per million against $0.30/$2.50 here, and
 *  doubles on January 1st 2027 where this one holds. Same capabilities on all
 *  three things a scan needs — image input, a JSON schema, Google Search
 *  grounding — and there is no Lite at the 3.6 generation to compare against.
 *  What it costs is priced in `server/domain/admin/business-rules.ts`; changing
 *  the model here means changing the rates there.
 */
const GEMINI_MODEL = 'gemini-3.5-flash-lite'

const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

const logger = createLogger('scan')

/** What Gemini reports a call cost. Thinking tokens bill at the output rate and
 *  are the largest line on a scan, which is why they are read separately rather
 *  than trusted to be inside `candidatesTokenCount`.
 *
 *  `billedToolCalls` is what the invoice counts for a grounded call — each search
 *  the model chose to run is billed on its own. */
type GeminiUsage = {
  promptTokenCount?: number
  candidatesTokenCount?: number
  thoughtsTokenCount?: number
  billedToolCalls?: { tool?: string; successfulToolCallCount?: number }[]
}

export type GeminiResponse = {
  candidates?: {
    content?: { parts?: { text?: string }[] }
    /** The searches the model ran, when it says so. */
    groundingMetadata?: { webSearchQueries?: string[] }
  }[]
  usageMetadata?: GeminiUsage
}

type Part = { text: string } | { inline_data: { mime_type: string; data: string } }

type GenerateOptions = {
  step: string
  parts: Part[]
  responseSchema: unknown
  /** Grounding is what makes enrichment and cataloguing worth their cost; the
   *  vision step must NOT use it, since the answer is in the image. */
  grounded?: boolean
}

/** One call to the model, returning the decoded JSON and what it consumed.
 *
 *  `usage` is captured on every step so the allowance and the price can be
 *  recalibrated against measured tokens rather than an estimate — Vinarium's
 *  first costing was four times under for exactly the want of this.
 *
 *  An answer that cannot be read is asked for once more. A grounded step reads
 *  its JSON out of free text, and now and then that text is not valid JSON — an
 *  unescaped quote in a title, a string left open, the object said twice. It is
 *  rare and does not repeat: eight grounded calls for the very work that failed
 *  on September 25th 2026 all answered cleanly. One retry, not a loop: a second
 *  unreadable answer is a prompt to look at, and its text travels in the error
 *  so Sentry shows it. The unread answer was billed all the same, so its usage
 *  is added to the one returned.
 */
export const generate = async <T>(
  options: GenerateOptions,
): Promise<{ value: T; usage?: AiStepUsage }> => {
  try {
    return await answeredOnce<T>(options)
  } catch (error) {
    if (!(error instanceof UnreadableAnswer)) throw error
    logger.warn('unreadable Gemini answer, asked again', { error, step: options.step })
    const { value, usage } = await answeredOnce<T>(options)
    return { value, usage: summedUsage(error.usage, usage) }
  }
}

/** An answer with nothing in it, or nothing JSON can read. Kept apart from a
 *  failed request, which asking again would not mend. */
class UnreadableAnswer extends Error {
  constructor(
    step: string,
    reason: string,
    text: string,
    readonly usage: AiStepUsage | undefined,
  ) {
    super(`${step}: ${reason}${text ? ` — ${text.slice(0, 2000)}` : ''}`)
    this.name = 'UnreadableAnswer'
  }
}

const answeredOnce = async <T>(
  options: GenerateOptions,
): Promise<{ value: T; usage?: AiStepUsage }> => {
  const { googleApiKey } = config()

  const response = await $fetch<GeminiResponse>(`${GEMINI_API_URL}?key=${googleApiKey}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: requestBodyOf(options),
  })
  const usage = capturedUsage(options.step, response, options.grounded === true)

  const text = response.candidates?.[0]?.content?.parts?.map((part) => part.text ?? '').join('')
  if (!text) throw new UnreadableAnswer(options.step, 'Gemini returned no content', '', usage)

  try {
    return { value: answerOf(text) as T, usage }
  } catch (error) {
    throw new UnreadableAnswer(options.step, (error as Error).message, text, usage)
  }
}

const summedUsage = (
  first: AiStepUsage | undefined,
  second: AiStepUsage | undefined,
): AiStepUsage | undefined =>
  first && second
    ? {
        promptTokens: first.promptTokens + second.promptTokens,
        outputTokens: first.outputTokens + second.outputTokens,
        thinkingTokens: first.thinkingTokens + second.thinkingTokens,
        searches: first.searches + second.searches,
      }
    : (first ?? second)

/** What is sent for one step.
 *
 *  A grounded step does not use the API's JSON mode. On Flash-Lite, Google
 *  Search combined with `responseMimeType: 'application/json'` answers 200 with
 *  no candidate at all — measured on September 22nd 2026: every call empty
 *  without a schema, one in three with one, against none out of ten for either
 *  option alone. So a grounded step describes its schema in the prompt and its
 *  answer is read out of free text; an ungrounded one keeps the API's guarantee.
 */
export const requestBodyOf = ({ parts, responseSchema, grounded }: GenerateOptions) =>
  grounded
    ? {
        contents: [{ parts: [...parts, { text: answerShape(responseSchema) }] }],
        tools: [{ google_search: {} }],
        generationConfig: undefined,
      }
    : {
        contents: [{ parts }],
        tools: undefined,
        generationConfig: { responseMimeType: 'application/json', responseSchema },
      }

/** Said as a description, because the model shown a bare schema sometimes
 *  answers with the schema itself. */
const answerShape = (schema: unknown) =>
  `Réponds UNIQUEMENT par l'objet JSON demandé, sans aucun texte autour. Le schéma JSON ci-dessous décrit la forme de cet objet ; c'est une description, ne le recopie pas :
${JSON.stringify(schema)}`

/** The JSON object in an answer. JSON mode returns it bare; free text may fence
 *  it or say a word around it, so the object is taken from its first brace to
 *  its last. */
export const answerOf = (text: string): unknown => {
  const start = text.indexOf('{')
  const end = text.lastIndexOf('}')
  if (start === -1 || end < start) throw new Error('Gemini answered without a JSON object')
  return JSON.parse(text.slice(start, end + 1))
}

const capturedUsage = (
  step: string,
  response: GeminiResponse,
  grounded: boolean,
): AiStepUsage | undefined => {
  const usage = response.usageMetadata
  if (!usage) return undefined
  const searches = billedSearches(response, grounded)
  logger.info(
    `${step}: ${usage.promptTokenCount ?? 0} in, ${usage.candidatesTokenCount ?? 0} out, ${usage.thoughtsTokenCount ?? 0} thinking, ${searches} searches`,
  )
  return {
    promptTokens: usage.promptTokenCount ?? 0,
    outputTokens: usage.candidatesTokenCount ?? 0,
    thinkingTokens: usage.thoughtsTokenCount ?? 0,
    searches,
  }
}

/** How many Google searches this call is billed for.
 *
 *  Two fields can answer, and both go missing when the model searched while
 *  thinking rather than while answering — Google has confirmed the gap and says
 *  `billedToolCalls` may disappear entirely, so neither can be the only source.
 *  A grounded call that reports nothing is therefore counted as one search
 *  rather than none: the whole point of the figure is to say what the month
 *  costs, and a zero there is the one answer that is certainly wrong.
 *
 *  So this is an estimate, not the invoice. It is exact whenever Gemini answers,
 *  and errs towards spending rather than towards a comfortable number. An
 *  ungrounded step never searches and is not guessed at.
 */
export const billedSearches = (response: GeminiResponse, grounded: boolean): number => {
  if (!grounded) return 0
  const billed = response.usageMetadata?.billedToolCalls?.reduce(
    (sum, call) => sum + (call.successfulToolCallCount ?? 0),
    0,
  )
  if (billed) return billed
  return response.candidates?.[0]?.groundingMetadata?.webSearchQueries?.length || 1
}
