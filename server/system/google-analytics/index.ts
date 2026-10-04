import { config } from '~/system/config/index'
import { createLogger } from '~/system/logger'
import { type DailySessionCount, parseSessionsReport } from './sessions-report'

const logger = createLogger('google-analytics')

// The GA4 Data API only takes a token carrying an Analytics scope, and the one
// firebase-admin hands out carries cloud-platform alone. The metadata server
// mints a token for any scope the runtime's service account is asked for.
const TOKEN_URL =
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' +
  '?scopes=https://www.googleapis.com/auth/analytics.readonly'

export namespace GoogleAnalytics {
  // How many sessions GA4 counted each day between two calendar days, both
  // included — the `session_start` events Firebase Analytics already sends. GA4
  // processes its data about a day late, so the last day or two read low.
  //
  // Returns undefined when the property is not configured, and off Cloud Run,
  // where there is no metadata server to mint the token: the screen then says
  // the sessions are unavailable.
  export const dailySessions = async (
    first: string,
    last: string,
  ): Promise<DailySessionCount[] | undefined> => {
    const { ga4PropertyId } = config()
    if (!ga4PropertyId || !process.env.K_SERVICE) return undefined

    const response = await fetch(
      `https://analyticsdata.googleapis.com/v1beta/properties/${ga4PropertyId}:runReport`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${await accessToken()}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          dateRanges: [{ startDate: first, endDate: last }],
          dimensions: [{ name: 'date' }],
          metrics: [{ name: 'sessions' }],
        }),
      },
    )
    if (!response.ok) {
      logger.error('GA4 runReport failed', { status: response.status })
      throw new Error(`GA4 runReport answered ${response.status}`)
    }
    return parseSessionsReport(await response.json())
  }

  const accessToken = async (): Promise<string> => {
    const response = await fetch(TOKEN_URL, { headers: { 'Metadata-Flavor': 'Google' } })
    if (!response.ok) throw new Error(`Metadata server answered ${response.status}`)
    const { access_token } = (await response.json()) as { access_token: string }
    return access_token
  }
}
