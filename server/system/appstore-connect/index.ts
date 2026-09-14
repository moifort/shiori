import { createPrivateKey, sign } from 'node:crypto'
import { gunzipSync } from 'node:zlib'
import { chunk } from 'lodash-es'
import type { Month } from '~/domain/shared/types'
import { config } from '~/system/config/index'
import { createLogger } from '~/system/logger'
import { parseSalesReport, premiumTotals } from './sales-report'

const API_URL = 'https://api.appstoreconnect.apple.com/v1/salesReports'

const logger = createLogger('appstore-connect')

export namespace AppStoreConnect {
  // What the App Store sold over the month so far, summed from its daily sales
  // reports (the monthly report only exists once the month has closed). Returns
  // undefined when the API key is not configured — the caller treats revenue as
  // simply unavailable. A day with no sales has no report (404) and counts zero.
  export const monthSales = async (
    month: Month,
  ): Promise<{ proceedsEur: number; grossEur: number } | undefined> => {
    const { ascIssuerId, ascKeyId, ascPrivateKey, ascVendorNumber } = config()
    if (!ascIssuerId || !ascKeyId || !ascPrivateKey || !ascVendorNumber) return undefined

    const jwt = apiToken(ascIssuerId, ascKeyId, ascPrivateKey)
    const totals = { proceedsEur: 0, grossEur: 0 }
    // Bounded parallelism: a full month is ~30 requests, well within Apple's
    // rate limit, but sequential would flirt with the function's 60s timeout.
    for (const days of chunk(elapsedDaysOf(month), 10)) {
      const reports = await Promise.all(days.map((day) => dailyReport(jwt, ascVendorNumber, day)))
      for (const report of reports) {
        if (!report) continue
        const { proceedsEur, grossEur } = premiumTotals(parseSalesReport(report))
        totals.proceedsEur += proceedsEur
        totals.grossEur += grossEur
      }
    }
    return totals
  }

  // The days of the month a daily report can exist for: from the 1st through
  // yesterday (UTC) — today's report is never ready, and a fully elapsed month
  // contributes every day it had.
  const elapsedDaysOf = (month: Month): string[] => {
    const [year, monthIndex] = (month as string).split('-').map(Number) as [number, number]
    const daysInMonth = new Date(Date.UTC(year, monthIndex, 0)).getUTCDate()
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000)
    const days: string[] = []
    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(Date.UTC(year, monthIndex - 1, day))
      if (date > yesterday) break
      days.push(`${month}-${String(day).padStart(2, '0')}`)
    }
    return days
  }

  // One day's SALES SUMMARY report, gunzipped to its TSV. Apple answers 404 for
  // a day with no sales (and for a report not generated yet) — that is a zero,
  // not an error. Anything else unexpected is: the caller keeps its last figure.
  const dailyReport = async (
    jwt: string,
    vendorNumber: string,
    day: string,
  ): Promise<string | undefined> => {
    const params = new URLSearchParams({
      'filter[frequency]': 'DAILY',
      'filter[reportDate]': day,
      'filter[reportType]': 'SALES',
      'filter[reportSubType]': 'SUMMARY',
      'filter[vendorNumber]': vendorNumber,
    })
    const response = await fetch(`${API_URL}?${params}`, {
      headers: { authorization: `Bearer ${jwt}` },
    })
    if (response.status === 404) return undefined
    if (!response.ok) {
      logger.error(`salesReports ${day} answered ${response.status}`)
      throw new Error(`App Store Connect salesReports answered ${response.status}`)
    }
    return gunzipSync(Buffer.from(await response.arrayBuffer())).toString('utf8')
  }

  // A short-lived App Store Connect API token: ES256 over the issuer and key
  // ids, signed with the .p8 private key. node:crypto emits the raw (r,s)
  // signature JOSE wants via `ieee-p1363`, so no JWT library is needed.
  const apiToken = (issuerId: string, keyId: string, privateKey: string): string => {
    const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url')
    const now = Math.floor(Date.now() / 1000)
    const header = encode({ alg: 'ES256', kid: keyId, typ: 'JWT' })
    const payload = encode({
      iss: issuerId,
      iat: now,
      exp: now + 10 * 60,
      aud: 'appstoreconnect-v1',
    })
    const signature = sign('sha256', Buffer.from(`${header}.${payload}`), {
      key: createPrivateKey(privateKey),
      dsaEncoding: 'ieee-p1363',
    }).toString('base64url')
    return `${header}.${payload}.${signature}`
  }
}
