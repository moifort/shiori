/**
 * What the deprecation routine can remove, and the build floor that goes with it — see
 * docs/api-evolution.md.
 *
 *   bun scripts/deprecations.ts
 *     One row per deprecated element of shared/schema.graphql: the first build that no
 *     longer asks for it, and whether it can go. Ends with the proposed
 *     MINIMUM_SUPPORTED_IOS_BUILD.
 *
 *   bun scripts/deprecations.ts check-floor
 *     Fails when MINIMUM_SUPPORTED_IOS_BUILD is above the build on sale on the App Store:
 *     a reader would be blocked with no update to install. Run by the Deploy workflow.
 *
 * Reads ASC_KEY_ID, ASC_ISSUER_ID and the key itself from ASC_KEY_P8 (its contents) or
 * ASC_KEY_PATH (a .p8 file). Without them the report still traces the builds and marks
 * every status unknown; check-floor fails unless the floor is still 1.
 */

import { createPrivateKey, sign } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { buildSchema } from 'graphql'
import { MINIMUM_SUPPORTED_IOS_BUILD } from '../server/system/app-support'
import {
  type LiveBuild,
  proposedFloorOf,
  type Since,
  type Status,
  statusOf,
} from './deprecations/status'
import { coordinatesUsedBy, deprecatedElementsOf } from './deprecations/usage'

const APP_ID = '6811938144'
const OPERATIONS = 'ios/*.graphql'

const git = (...args: string[]): string => {
  const result = Bun.spawnSync(['git', ...args], { stdout: 'pipe', stderr: 'pipe' })
  if (result.exitCode !== 0) {
    throw new Error(`git ${args.join(' ')} failed: ${result.stderr.toString().trim()}`)
  }
  return result.stdout.toString()
}

const lines = (text: string) => text.split('\n').filter((line) => line.length > 0)

/** The app's operations as they stood at a commit. */
const operationsAt = (commit: string): string[] =>
  lines(git('ls-tree', '-r', '--name-only', commit, '--', 'ios'))
    .filter((path) => path.endsWith('.graphql'))
    .map((path) => git('show', `${commit}:${path}`))

const buildOf = (commit: string) => Number(git('rev-list', '--count', commit).trim())

// MARK: - App Store Connect

const credentials = () => {
  const { ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_KEY_PATH } = process.env
  const key = ASC_KEY_P8 || (ASC_KEY_PATH ? readFileSync(ASC_KEY_PATH, 'utf8') : undefined)
  if (!ASC_KEY_ID || !ASC_ISSUER_ID || !key) return undefined
  return { keyId: ASC_KEY_ID, issuerId: ASC_ISSUER_ID, key }
}

const apiToken = ({ keyId, issuerId, key }: NonNullable<ReturnType<typeof credentials>>) => {
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url')
  const now = Math.floor(Date.now() / 1000)
  const unsigned = `${encode({ alg: 'ES256', kid: keyId, typ: 'JWT' })}.${encode({
    iss: issuerId,
    iat: now,
    exp: now + 15 * 60,
    aud: 'appstoreconnect-v1',
  })}`
  const signature = sign('sha256', Buffer.from(unsigned), {
    key: createPrivateKey(key),
    dsaEncoding: 'ieee-p1363',
  })
  return `${unsigned}.${signature.toString('base64url')}`
}

type Resource = {
  id: string
  type: string
  attributes: Record<string, unknown>
  relationships?: Record<string, { data?: { id: string } }>
}

/** The build on sale on the App Store and the day it was released — the date of
 *  its `ios-v<version>` tag, which the release workflow submits for automatic
 *  release. Undefined before the first release. */
const liveBuild = async (): Promise<LiveBuild | undefined | 'unknown'> => {
  const found = credentials()
  if (!found) return 'unknown'
  const response = await fetch(
    `https://api.appstoreconnect.apple.com/v1/apps/${APP_ID}/appStoreVersions` +
      '?filter[appStoreState]=READY_FOR_SALE&filter[platform]=IOS&include=build' +
      '&fields[appStoreVersions]=versionString,build&fields[builds]=version',
    { headers: { authorization: `Bearer ${apiToken(found)}` } },
  )
  if (!response.ok) {
    throw new Error(`App Store Connect answered ${response.status}: ${await response.text()}`)
  }
  const { data, included = [] } = (await response.json()) as {
    data: Resource[]
    included?: Resource[]
  }
  const [version] = data
  if (!version) return undefined
  const buildId = version.relationships?.build?.data?.id
  const build = included.find((resource) => resource.type === 'builds' && resource.id === buildId)
  if (!build) throw new Error(`The version on sale lists no build: ${JSON.stringify(version)}`)
  const tag = `ios-v${version.attributes.versionString}`
  const tagged = git('log', '-1', '--format=%cI', `refs/tags/${tag}`).trim()
  return { build: Number(build.attributes.version), releasedOn: new Date(tagged) }
}

// MARK: - Commands

const describe = (status: Status): string => {
  switch (status.kind) {
    case 'still-asked':
      return 'still asked by the app'
    case 'removable':
      return 'removable'
    case 'in-grace':
      return `in grace until ${status.until.toISOString().slice(0, 10)}`
    case 'waiting-release':
      return 'waiting for a release'
    case 'unknown':
      return 'unknown (no App Store credentials)'
  }
}

const report = async () => {
  const schema = buildSchema(readFileSync('shared/schema.graphql', 'utf8'))
  const elements = deprecatedElementsOf(schema)
  const traceable = elements.filter((element) => element.traceable)
  const askedNow = coordinatesUsedBy(schema, operationsAt('HEAD'))

  // Walk back through the commits that touched the operations until each element
  // is found in use: the newer commit walked just before stopped asking for it.
  const since = new Map<string, Since>()
  for (const { coordinate } of traceable) {
    if (askedNow.has(coordinate)) since.set(coordinate, 'still-asked')
  }
  let newer: string | undefined
  for (const commit of lines(git('log', '--format=%H', 'HEAD', '--', OPERATIONS))) {
    const pending = traceable.filter(({ coordinate }) => !since.has(coordinate))
    if (pending.length === 0) break
    let used: Set<string>
    try {
      used = coordinatesUsedBy(schema, operationsAt(commit))
    } catch (error) {
      process.stderr.write(`Skipping ${commit.slice(0, 7)}, unparsable: ${error}\n`)
      newer = commit
      continue
    }
    for (const { coordinate } of pending) {
      if (used.has(coordinate) && newer) since.set(coordinate, buildOf(newer))
    }
    newer = commit
  }

  const live = await liveBuild()
  const today = new Date()
  const rows = traceable.map(({ coordinate }) => {
    const first = since.get(coordinate) ?? 0
    return { coordinate, since: first, status: statusOf({ since: first, live, today }) }
  })
  const width = Math.max(40, ...elements.map((element) => element.coordinate.length + 2))
  const out = [`${'element'.padEnd(width)}${'no longer asked since'.padEnd(24)}status`]
  for (const row of rows) {
    const build = typeof row.since === 'number' ? `build ${row.since}` : '—'
    out.push(`${row.coordinate.padEnd(width)}${build.padEnd(24)}${describe(row.status)}`)
  }
  for (const element of elements.filter((element) => !element.traceable)) {
    out.push(`${element.coordinate.padEnd(width)}${'—'.padEnd(24)}check by hand`)
  }
  if (elements.length === 0) out.push('(nothing is deprecated)')
  out.push(
    '',
    `Live on the App Store: ${
      live === 'unknown'
        ? 'unknown (no App Store credentials)'
        : live
          ? `build ${live.build}, released ${live.releasedOn.toISOString().slice(0, 10)}`
          : 'nothing yet'
    }`,
    `Proposed MINIMUM_SUPPORTED_IOS_BUILD: ${proposedFloorOf(rows, MINIMUM_SUPPORTED_IOS_BUILD)} ` +
      `(today ${MINIMUM_SUPPORTED_IOS_BUILD})`,
  )
  process.stdout.write(`${out.join('\n')}\n`)
}

const checkFloor = async () => {
  if (MINIMUM_SUPPORTED_IOS_BUILD <= 1) {
    process.stdout.write('The floor is 1: every build is supported.\n')
    return
  }
  const live = await liveBuild()
  if (live === 'unknown')
    throw new Error('App Store Connect credentials are needed to check the floor')
  if (!live) {
    throw new Error(
      `MINIMUM_SUPPORTED_IOS_BUILD is ${MINIMUM_SUPPORTED_IOS_BUILD} but nothing is on the App Store`,
    )
  }
  if (MINIMUM_SUPPORTED_IOS_BUILD > live.build) {
    throw new Error(
      `MINIMUM_SUPPORTED_IOS_BUILD is ${MINIMUM_SUPPORTED_IOS_BUILD}, above build ${live.build} ` +
        'on sale on the App Store: readers would be blocked with no update to install',
    )
  }
  process.stdout.write(
    `The floor ${MINIMUM_SUPPORTED_IOS_BUILD} is at or below build ${live.build} on sale.\n`,
  )
}

const [command] = process.argv.slice(2)
try {
  if (command === undefined) await report()
  else if (command === 'check-floor') await checkFloor()
  else throw new Error(`Unknown command ${command}: expected none or check-floor`)
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : error}\n`)
  process.exit(1)
}
