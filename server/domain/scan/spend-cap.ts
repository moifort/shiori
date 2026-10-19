/** Every Gemini call refused for want of money: the project's monthly spending
 *  cap reached, or its prepaid credits spent. Nothing the reader did, and
 *  nothing a retry fixes until someone tops the project up in AI Studio.
 *
 *  Apart from `gemini.ts`, which tests replace wholesale, so a caller can tell
 *  this refusal from any other failure whether the model is real or faked. */
export class SpendCapReached extends Error {
  /** Read by the logger: one issue for the cap, whichever caller hit it. */
  readonly fingerprint = ['gemini-spend-cap']
  /** Which of the two Google refused on: they are topped up on two different
   *  screens of AI Studio — the prepaid balance under Facturation, the monthly
   *  cap under Dépenses — and on 2026-10-19 a message naming both sent the
   *  reader to a cap that was fine. */
  constructor(
    readonly spent: 'prepaid-credits' | 'monthly-cap',
    options?: ErrorOptions,
  ) {
    super(
      spent === 'prepaid-credits'
        ? 'Gemini prepaid credits spent (402)'
        : 'Gemini monthly spending cap reached (429)',
      options,
    )
    this.name = 'SpendCapReached'
  }
}

export const isSpendCapReached = (error: unknown): error is SpendCapReached =>
  error instanceof SpendCapReached
