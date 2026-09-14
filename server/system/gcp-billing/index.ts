import { applicationDefault, getApp } from 'firebase-admin/app'
import type { Month } from '~/domain/shared/types'
import { config } from '~/system/config/index'
import { createLogger } from '~/system/logger'

const logger = createLogger('gcp-billing')

export namespace GcpBilling {
  // What GCP billed this project for one month, read from the billing export
  // table in BigQuery (the only place actual spend exists — no REST endpoint
  // serves it). Returns undefined when the export table is not configured.
  // Credits (free tier, promotions) are folded in, so this is what the invoice
  // really says; a credit surplus clamps at zero rather than showing income.
  export const monthCost = async (month: Month): Promise<number | undefined> => {
    const { gcpBillingTable } = config()
    if (!gcpBillingTable) return undefined
    const [project] = (gcpBillingTable as string).split('.') as [string]

    const query =
      'SELECT SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)) ' +
      `FROM \`${gcpBillingTable}\` ` +
      'WHERE invoice.month = @month AND project.id = @project'

    const response = await fetch(
      `https://bigquery.googleapis.com/bigquery/v2/projects/${project}/queries`,
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
            // The export keys its months "202607", without the dash.
            parameter('month', (month as string).replace('-', '')),
            parameter('project', project),
          ],
          timeoutMs: 30_000,
        }),
      },
    )
    if (!response.ok) {
      logger.error(`BigQuery query answered ${response.status}`)
      throw new Error(`BigQuery billing query answered ${response.status}`)
    }
    const result = (await response.json()) as {
      jobComplete?: boolean
      rows?: { f: { v: string | null }[] }[]
    }
    if (!result.jobComplete) throw new Error('BigQuery billing query did not complete in time')
    // SUM over an empty month is NULL — a month with no line items costs nothing.
    const value = Number(result.rows?.[0]?.f?.[0]?.v ?? 0)
    return Math.max(0, value)
  }

  const parameter = (name: string, value: string) => ({
    name,
    parameterType: { type: 'STRING' },
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
