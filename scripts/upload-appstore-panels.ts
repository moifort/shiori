#!/usr/bin/env bun
/**
 * Uploads the App Store panels of screenshots/appstore/<lang>/ to the editable
 * version of the app, one language at a time. Run from the Mac, before the
 * release tag: a version in review refuses new screenshots.
 *
 * It replaces rather than adds: the 6.9" set of each locale is emptied first, the
 * panels go up in filename order, and the run ends by counting what the store
 * actually holds. That counting is the point — `fastlane deliver` once put every
 * Vinarium panel up twice, on a run it reported as green.
 *
 *   bun scripts/upload-appstore-panels.ts           # upload
 *   bun scripts/upload-appstore-panels.ts --check   # count only: what the release runs
 */
import { createHash } from 'node:crypto'
import { readdir, readFile } from 'node:fs/promises'
import { basename, join } from 'node:path'
import { api, type Collection, editableVersion, patch, post, type Single } from './appstore/connect'

// The panels are 1320x2868, the 6.9" size; App Store Connect files that size under
// the 6.7" display type, which covers every large iPhone.
const DISPLAY_TYPE = 'APP_IPHONE_67'

/** The App Store locales the listing is written in, by capture language. */
const LOCALES: Record<string, string> = { fr: 'fr-FR', en: 'en-US' }

type Screenshot = { fileName: string }
type UploadOperation = {
  method: string
  url: string
  offset: number
  length: number
  requestHeaders: { name: string; value: string }[]
}

const panelsOf = async (language: string) => {
  const directory = join(import.meta.dir, '..', 'screenshots', 'appstore', language)
  const panels = (await readdir(directory).catch(() => []))
    .filter((file) => file.endsWith('.png'))
    .sort()
  if (panels.length === 0)
    throw new Error(
      `No panels in screenshots/appstore/${language} — run \`bun scripts/generate-appstore-previews.ts\` first`,
    )
  return panels.map((panel) => join(directory, panel))
}

const screenshotSet = async (localizationId: string, create: boolean) => {
  const sets = await api<Collection<{ screenshotDisplayType: string }>>(
    `/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets`,
  )
  const existing = sets.data.find((s) => s.attributes.screenshotDisplayType === DISPLAY_TYPE)
  if (existing || !create) return existing?.id
  const created = await post<Single<unknown>>('/v1/appScreenshotSets', {
    type: 'appScreenshotSets',
    attributes: { screenshotDisplayType: DISPLAY_TYPE },
    relationships: {
      appStoreVersionLocalization: {
        data: { type: 'appStoreVersionLocalizations', id: localizationId },
      },
    },
  })
  return created.data.id
}

const screenshotsIn = async (setId: string) =>
  (await api<Collection<Screenshot>>(`/v1/appScreenshotSets/${setId}/appScreenshots?limit=50`)).data

const upload = async (setId: string, path: string) => {
  const bytes = await readFile(path)
  const reserved = await post<Single<{ uploadOperations: UploadOperation[] }>>(
    '/v1/appScreenshots',
    {
      type: 'appScreenshots',
      attributes: { fileSize: bytes.length, fileName: basename(path) },
      relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: setId } } },
    },
  )
  // The store hands back the byte ranges it wants and where to PUT each of them.
  for (const operation of reserved.data.attributes.uploadOperations) {
    const headers = Object.fromEntries(operation.requestHeaders.map((h) => [h.name, h.value]))
    const response = await fetch(operation.url, {
      method: operation.method,
      headers,
      body: bytes.subarray(operation.offset, operation.offset + operation.length),
    })
    if (!response.ok) throw new Error(`${operation.method} ${basename(path)} → ${response.status}`)
  }
  await patch(`/v1/appScreenshots/${reserved.data.id}`, {
    type: 'appScreenshots',
    id: reserved.data.id,
    attributes: {
      uploaded: true,
      sourceFileChecksum: createHash('md5').update(bytes).digest('hex'),
    },
  })
  return reserved.data.id
}

const checkOnly = process.argv.includes('--check')
const version = await editableVersion()
console.log(`Version ${version.attributes.versionString} (${version.attributes.appStoreState})`)

const localizations = await api<Collection<{ locale: string }>>(
  `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`,
)

let missing = false
for (const [language, locale] of Object.entries(LOCALES)) {
  const panels = await panelsOf(language)
  const localization = localizations.data.find((l) => l.attributes.locale === locale)
  if (!localization) throw new Error(`The version has no ${locale} localization`)
  const setId = await screenshotSet(localization.id, !checkOnly)

  if (checkOnly) {
    const held = setId ? (await screenshotsIn(setId)).length : 0
    console.log(`${locale}: ${held} on the store, ${panels.length} in the repository`)
    if (held !== panels.length) missing = true
    continue
  }
  if (!setId) throw new Error(`No screenshot set for ${locale}`)

  for (const screenshot of await screenshotsIn(setId))
    await api(`/v1/appScreenshots/${screenshot.id}`, { method: 'DELETE' })

  const uploaded: string[] = []
  for (const panel of panels) uploaded.push(await upload(setId, panel))

  // Order is the reading order in the store, and it is not the upload order.
  await api(`/v1/appScreenshotSets/${setId}/relationships/appScreenshots`, {
    method: 'PATCH',
    body: JSON.stringify({ data: uploaded.map((id) => ({ type: 'appScreenshots', id })) }),
  })

  const names = (await screenshotsIn(setId)).map((s) => s.attributes.fileName)
  if (names.length !== panels.length)
    throw new Error(
      `${locale}: ${names.length} screenshots on the store for ${panels.length} panels`,
    )
  console.log(`${locale}: ${names.join(' ')}`)
}

if (missing) {
  console.error(
    'The version does not hold its panels: run `bun scripts/upload-appstore-panels.ts` from the Mac before tagging.',
  )
  process.exit(1)
}
