/** One day of the bill, in the billing currency (EUR on this account). */
export type BilledDay = { day: string; geminiEur: number; infraEur: number }

type QueryResult = {
  jobComplete?: boolean
  rows?: { f: { v: string | null }[] }[]
}

// BigQuery's answer → one entry per billed day. A day whose credits exceed its
// cost (the free tier covering a function's whole day) clamps at zero rather
// than reading as income — and rather than a negative amount, which no euro
// figure of ours can hold.
export const parseDailyCosts = (result: QueryResult): BilledDay[] => {
  if (!result.jobComplete) throw new Error('BigQuery billing query did not complete in time')
  return (result.rows ?? []).map(({ f: [day, gemini, infra] }) => ({
    day: String(day?.v),
    geminiEur: Math.max(0, Number(gemini?.v ?? 0)),
    infraEur: Math.max(0, Number(infra?.v ?? 0)),
  }))
}
