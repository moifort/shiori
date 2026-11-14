/** What a model call consumed, and how grounded calls are billed: the figures
 *  the scan metrics, the admin's price and the switch to Claude read. */

/** What one Gemini step consumed. Thinking tokens bill at the output rate and
 *  are the largest line on a scan, so they are kept apart rather than folded
 *  into the output count: the allowance and the price are sized on them.
 *
 *  `searches` is the Google searches a grounded step ran, billed per search on
 *  top of the tokens and past a few thousand a month the larger of the two. An
 *  ungrounded step is always zero. */
export type AiStepUsage = {
  promptTokens: number
  outputTokens: number
  thinkingTokens: number
  searches: number
}

/** Two calls made for one step, billed as one. */
export const summedUsage = (
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

/** The Google searches Gemini bills free each month. */
export const FREE_GEMINI_SEARCHES = 5000

/** The searches one grounded Gemini call is billed for, measured: 421 for 67
 *  calls on 2026-10-19, 450 for 107 on 2026-10-12 counting the shelf's
 *  ungrounded ones. Gemini's own figure says a fourth of it, so the bill is
 *  read from the calls instead. */
export const SEARCHES_PER_GROUNDED_CALL = 6.3

/** How far under the free searches the grounded steps move to Claude: the
 *  ratio is an average, and a shelf scan runs twenty calls in a minute. */
const FREE_SEARCHES_MARGIN = 500

/** Whether this month's grounded Gemini calls have spent the free searches,
 *  give or take the margin: past it, every search is billed, and Claude's are
 *  paid from the Anthropic credit instead. */
export const freeSearchesSpent = (groundedCalls: number): boolean =>
  groundedCalls * SEARCHES_PER_GROUNDED_CALL >= FREE_GEMINI_SEARCHES - FREE_SEARCHES_MARGIN
