import { applicationDefault, getApp } from 'firebase-admin/app'
import type { Month } from '~/domain/shared/types'
import { config } from '~/system/config/index'
import { createLogger } from '~/system/logger'
import { type BilledDay, parseDailyCosts } from './daily-costs'

const logger = createLogger('gcp-billing')

// How the export names the Gemini API. Every other service of the project is
// infrastructure (functions, Firestore, storage, scheduler…).
const GEMINI_SERVICE = 'Gemini API'

// One day's net amount: its cost plus its credits (the free tier, negative).
const NET = 'cost + IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)'

export namespace GcpBilling {
  // What the bill says each day of the month cost this project, read from the
  // billing export in BigQuery — the only place actual spend exists, and what
  // AI Studio's Spend page shows. The export holds every project on the billing
  // account and lives wherever it was set up (Vinarium's project, today), so the
  // rows are filtered on this function's own project, and the job runs here.
  //
  // The export lags about a day: today, and often yesterday, have no rows yet.
  // Returns undefined when the table or the project id is not configured.
  export const dailyCosts = async (month: Month): Promise<BilledDay[] | undefined> => {
    const { gcpBillingTable, gcpProjectId } = config()
    if (!gcpBillingTable || !gcpProjectId) return undefined

    const query =
      `SELECT CAST(DATE(usage_start_time) AS STRING) AS day, ` +
      `SUM(IF(service.description = @gemini, ${NET}, 0)), ` +
      `SUM(IF(service.description = @gemini, 0, ${NET})) ` +
      `FROM \`${gcpBillingTable}\` ` +
      'WHERE project.id = @project AND DATE(usage_start_time) BETWEEN @first AND @last ' +
      'GROUP BY day ORDER BY day'

    const [year, index] = (month as string).split('-').map(Number) as [number, number]
    const lastDay = new Date(Date.UTC(year, index, 0)).getUTCDate()
    const response = await fetch(
      `https://bigquery.googleapis.com/bigquery/v2/projects/${gcpProjectId}/queries`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${await accessToken()}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          query,
          useLegacySql: false,
          parameterMode: 'NAMED',
          queryParameters: [
            parameter('gemini', 'STRING', GEMINI_SERVICE),
            parameter('project', 'STRING', gcpProjectId),
            parameter('first', 'DATE', `${month}-01`),
            parameter('last', 'DATE', `${month}-${String(lastDay).padStart(2, '0')}`),
          ],
          timeoutMs: 30_000,
        }),
      },
    )
    if (!response.ok) {
      logger.error('BigQuery query failed', { status: response.status })
      throw new Error(`BigQuery billing query answered ${response.status}`)
    }
    return parseDailyCosts(await response.json())
  }

  const parameter = (name: string, type: 'STRING' | 'DATE', value: string) => ({
    name,
    parameterType: { type },
    parameterValue: { value },
  })

  // The function's own service account, through the credential firebase-admin
  // already holds — no extra auth library for one bearer token. getApp() is
  // safe here: the auth middleware initializes firebase-admin at boot, long
  // before any refresh can run (and applicationDefault() covers a bare use).
  const accessToken = async (): Promise<string> => {
    const credential = getApp().options.credential ?? applicationDefault()
    const { access_token } = await credential.getAccessToken()
    return access_token
  }
}
