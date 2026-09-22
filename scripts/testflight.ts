/**
 * The two App Store Connect questions the iOS upload workflow asks, answered from a Linux
 * runner with the team API key rather than through fastlane.
 *
 *   bun scripts/testflight.ts check <marketing> <build>
 *     Prints `exists=true|false` and `previous=<build number of the last upload>` as
 *     GitHub step outputs. A build number is the commit count, so a build that already
 *     exists means this commit is already on App Store Connect and there is nothing to do.
 *
 *   bun scripts/testflight.ts notes <marketing> <build> <file>
 *     Waits for the uploaded build to show up, sets the file as its TestFlight
 *     "What to Test", then waits for processing to finish so the run only turns green once
 *     testers can actually install it.
 *
 * Reads ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8 (the .p8 contents) from the environment.
 */

import { createPrivateKey, sign } from 'node:crypto'
import { readFileSync } from 'node:fs'

const BUNDLE_ID = 'com.polyforms.shiori.app'
// Beta testers get "What to Test" in their own language when it exists, and the app ships
// in these two. Commit subjects are English, so both carry the same text.
const LOCALES = ['fr-FR', 'en-US']
const WHATS_NEW_MAX = 4000

const env = (name: string) => {
  const value = process.env[name]
  if (!value) throw new Error(`${name} is unset`)
  return value
}

const apiToken = () => {
  const kid = env('ASC_KEY_ID')
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url')
  const now = Math.floor(Date.now() / 1000)
  const unsigned = `${encode({ alg: 'ES256', kid, typ: 'JWT' })}.${encode({
    iss: env('ASC_ISSUER_ID'),
    iat: now,
    exp: now + 15 * 60,
    aud: 'appstoreconnect-v1',
  })}`
  const signature = sign('sha256', Buffer.from(unsigned), {
    key: createPrivateKey(env('ASC_KEY_P8')),
    dsaEncoding: 'ieee-p1363',
  })
  return `${unsigned}.${signature.toString('base64url')}`
}

type Resource = { id: string; attributes: Record<string, unknown> }

// A fresh token per call: `notes` polls for up to an hour, well past a token's lifetime.
const api = async (method: string, path: string, body?: object) => {
  const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    method,
    headers: { authorization: `Bearer ${apiToken()}`, 'content-type': 'application/json' },
    body: body && JSON.stringify(body),
  })
  if (!response.ok) {
    throw new Error(`${method} ${path} answered ${response.status}: ${await response.text()}`)
  }
  return (await response.json()) as { data: Resource[] | Resource }
}

const list = async (path: string) => (await api('GET', path)).data as Resource[]

const appId = async () => {
  const [app] = await list(`/v1/apps?filter[bundleId]=${BUNDLE_ID}`)
  if (!app) throw new Error(`No App Store Connect app for ${BUNDLE_ID}`)
  return app.id
}

const findBuild = async (app: string, marketing: string, build: string) => {
  const [found] = await list(
    `/v1/builds?filter[app]=${app}&filter[version]=${build}` +
      `&filter[preReleaseVersion.version]=${marketing}&fields[builds]=version,processingState`,
  )
  return found
}

const output = (lines: string[]) => process.stdout.write(`${lines.join('\n')}\n`)

const check = async (marketing: string, build: string) => {
  const app = await appId()
  const existing = await findBuild(app, marketing, build)
  const [latest] = await list(
    `/v1/builds?filter[app]=${app}&sort=-uploadedDate&limit=1&fields[builds]=version`,
  )
  output([`exists=${existing !== undefined}`, `previous=${latest?.attributes.version ?? ''}`])
}

const poll = async <T>(what: string, attempt: () => Promise<T | undefined>) => {
  // App Store Connect usually lists a build within five minutes of the upload and finishes
  // processing it within twenty; an hour means something is wrong on Apple's side.
  for (let tries = 0; tries < 60; tries++) {
    const result = await attempt()
    if (result !== undefined) return result
    process.stdout.write(`Waiting for ${what}…\n`)
    await Bun.sleep(60_000)
  }
  throw new Error(`Gave up waiting for ${what}`)
}

const notes = async (marketing: string, build: string, file: string) => {
  const whatsNew = readFileSync(file, 'utf8').trim().slice(0, WHATS_NEW_MAX)
  const app = await appId()
  const { id } = await poll(`build ${marketing} (${build}) to be listed`, () =>
    findBuild(app, marketing, build),
  )

  const existing = await list(`/v1/builds/${id}/betaBuildLocalizations`)
  for (const locale of LOCALES) {
    const localization = existing.find((item) => item.attributes.locale === locale)
    if (localization) {
      await api('PATCH', `/v1/betaBuildLocalizations/${localization.id}`, {
        data: { type: 'betaBuildLocalizations', id: localization.id, attributes: { whatsNew } },
      })
    } else {
      await api('POST', '/v1/betaBuildLocalizations', {
        data: {
          type: 'betaBuildLocalizations',
          attributes: { locale, whatsNew },
          relationships: { build: { data: { type: 'builds', id } } },
        },
      })
    }
  }
  process.stdout.write(`What to Test set on ${marketing} (${build}):\n${whatsNew}\n`)

  const state = await poll(`build ${marketing} (${build}) to finish processing`, async () => {
    const found = await findBuild(app, marketing, build)
    const processing = found?.attributes.processingState
    return processing === 'PROCESSING' ? undefined : processing
  })
  if (state !== 'VALID') throw new Error(`Build ${marketing} (${build}) ended ${state}`)
  process.stdout.write(`Build ${marketing} (${build}) is available in TestFlight\n`)
}

const [command, marketing, build, file] = process.argv.slice(2)
if (!marketing || !build) throw new Error('Usage: testflight.ts check|notes <marketing> <build>')
if (command === 'check') await check(marketing, build)
else if (command === 'notes' && file) await notes(marketing, build, file)
else throw new Error(`Unknown command: ${command}`)
