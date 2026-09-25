/**
 * Runs the real scan pipeline against the real Gemini API, with the Firestore
 * fake standing in for storage. A manual check, never part of `bun test`: it
 * costs money and its answers are not deterministic.
 *
 * Usage: NITRO_GOOGLE_API_KEY=... bun scripts/try-scan.ts <path-to-cover.jpg> [fr|en]
 */

import { mock } from 'bun:test'
import { readFileSync } from 'node:fs'
import { fakeDb, resetFakeFirestore } from '../server/test/fake-firestore'

const [, , imagePath = 'cover.jpg', language = 'fr'] = process.argv

const apiKey = process.env.NITRO_GOOGLE_API_KEY
if (!apiKey) {
  process.stderr.write('NITRO_GOOGLE_API_KEY is unset\n')
  process.exit(1)
}

// `$fetch` is a Nitro auto-import and does not exist outside its runtime. The
// scan code uses it exactly as the deployed function does, so the script
// provides the same implementation rather than changing the code under test.
const { ofetch } = await import('ofetch')
;(globalThis as unknown as { $fetch: typeof ofetch }).$fetch = ofetch

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config', () => ({ config: () => ({ googleApiKey: apiKey }) }))
resetFakeFirestore()

const { ScanCommand } = await import('~/domain/scan/command')
const { SeriesQuery } = await import('~/domain/series/query')

const image = readFileSync(imagePath)
process.stdout.write(`Scanning ${imagePath} (${image.byteLength} bytes) in ${language}\n\n`)

const started = Date.now()
const { result, cacheHit, usage } = await ScanCommand.scanWithCache(image, language as 'fr' | 'en')

process.stdout.write(`${JSON.stringify(result, null, 2)}\n\n`)
process.stdout.write(`cacheHit: ${cacheHit}\n`)
process.stdout.write(`usage: ${JSON.stringify(usage)}\n`)
process.stdout.write(`elapsed: ${((Date.now() - started) / 1000).toFixed(1)}s\n`)

if (result.series) {
  const series = await SeriesQuery.byId(result.series.id)
  process.stdout.write(`\ncatalogue: ${JSON.stringify(series, null, 2)}\n`)
}
