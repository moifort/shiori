/**
 * Proves, against a real Amazon account, the one thing the Kindle connection
 * rests on: that a Kindle device registered over PKCE mints website cookies that
 * open "Manage your content and devices".
 *
 * Run by the account's owner, by hand, never in CI:
 *
 *   bun scripts/kindle-probe.ts fr
 *
 * It prints a sign-in URL; sign in in a browser, then paste back the URL the
 * browser lands on (`/ap/maplanding?...openid.oa2.authorization_code=...`). It
 * registers a device, reads the library once, prints counts — never a title —
 * and keeps nothing: remove the "Kindle for iPhone" device it registered from
 * the Amazon account afterwards.
 */
import { createInterface } from 'node:readline/promises'
import type { KindleLocale } from 'kindle-api-ts'
import { library, login, register } from 'kindle-api-ts'

const locale = (process.argv[2] ?? 'fr') as KindleLocale
const { loginUrl, session } = await login(locale)

process.stdout.write(`\nSign in here, then paste the URL the browser lands on:\n\n${loginUrl}\n\n`)
const prompt = createInterface({ input: process.stdin, output: process.stdout })
const landing = (await prompt.question('Landing URL: ')).trim()
prompt.close()

const code = new URL(landing).searchParams.get('openid.oa2.authorization_code')
if (!code) throw new Error('No openid.oa2.authorization_code in that URL')

const credentials = await register(code, session)
process.stdout.write('Device registered.\n')

const titles = await library(credentials)
const count = (predicate: (title: (typeof titles)[number]) => boolean) =>
  titles.filter(predicate).length

process.stdout.write(
  [
    `Titles on the account: ${titles.length}`,
    `  read: ${count((title) => title.readStatus === 'READ')}`,
    `  dictionaries: ${count((title) => title.originType === 'KindleDictionary')}`,
    `  samples: ${count((title) => title.category.endsWith('Sample'))}`,
    '',
    'The connection works. Remove the "Kindle for iPhone" device this registered from',
    'the Amazon account (Manage your content and devices > Devices).',
    '',
  ].join('\n'),
)
