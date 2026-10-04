/** One day's sessions, as GA4 counted them. */
export type DailySessionCount = { day: string; sessions: number }

type RunReportResponse = {
  rows?: { dimensionValues?: { value?: string }[]; metricValues?: { value?: string }[] }[]
}

// GA4's runReport answer → one entry per day, in day order. GA4 writes the date
// dimension `20261004` and every metric as a string. A day without a single
// session has no row: the chart draws nothing for it, which is what it was.
export const parseSessionsReport = (report: RunReportResponse): DailySessionCount[] =>
  (report.rows ?? [])
    .flatMap(({ dimensionValues, metricValues }) => {
      const date = dimensionValues?.[0]?.value
      if (!date || !/^\d{8}$/.test(date)) return []
      const day = `${date.slice(0, 4)}-${date.slice(4, 6)}-${date.slice(6, 8)}`
      return [{ day, sessions: Number(metricValues?.[0]?.value ?? 0) }]
    })
    .sort((a, b) => (a.day < b.day ? -1 : 1))
