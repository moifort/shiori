/**
 * The App Store Connect API, as the App Store scripts call it.
 *
 * Signs with the team key the release workflow uses. On the Mac the key is found
 * where Xcode and `altool` look for it; in CI the three variables say where it is.
 *   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
 */
import { createSign } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'

export const BUNDLE_ID = 'com.polyforms.shiori.app'

const keyId = process.env.ASC_KEY_ID ?? 'M7447599QX'
const issuerId = process.env.ASC_ISSUER_ID ?? '58ccb3ea-10df-4d1e-ae5c-02fba75ab425'
const keyPath =
  process.env.ASC_KEY_PATH ??
  join(homedir(), '.appstoreconnect/private_keys', `AuthKey_${keyId}.p8`)

/** A token lives twenty minutes, longer than any of these scripts. */
const token = (() => {
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url')
  const now = Math.floor(Date.now() / 1000)
  const head = encode({ alg: 'ES256', kid: keyId, typ: 'JWT' })
  const claims = encode({ iss: issuerId, iat: now, exp: now + 20 * 60, aud: 'appstoreconnect-v1' })
  const signer = createSign('SHA256')
  signer.update(`${head}.${claims}`)
  const signature = signer
    .sign({ key: readFileSync(keyPath, 'utf8'), dsaEncoding: 'ieee-p1363' })
    .toString('base64url')
  return `${head}.${claims}.${signature}`
})()

/** What the API answers: resources carrying typed attributes. */
export type Resource<Attributes> = {
  id: string
  type: string
  attributes: Attributes
  relationships?: Record<string, { data?: { id: string; type: string } | null }>
}
export type Collection<Attributes> = { data: Resource<Attributes>[]; included?: Resource<never>[] }
export type Single<Attributes> = { data: Resource<Attributes> }

export const api = async <T>(path: string, init: RequestInit = {}): Promise<T> => {
  const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  })
  if (!response.ok)
    throw new Error(`${init.method ?? 'GET'} ${path} → ${response.status} ${await response.text()}`)
  return (response.status === 204 ? undefined : await response.json()) as T
}

export const post = <T>(path: string, data: unknown) =>
  api<T>(path, { method: 'POST', body: JSON.stringify({ data }) })

export const patch = <T>(path: string, data: unknown) =>
  api<T>(path, { method: 'PATCH', body: JSON.stringify({ data }) })

export const appId = async () => {
  const apps = await api<Collection<{ bundleId: string }>>(`/v1/apps?filter[bundleId]=${BUNDLE_ID}`)
  const id = apps.data[0]?.id
  if (!id) throw new Error(`No app for ${BUNDLE_ID}`)
  return id
}

type Version = { versionString: string; appStoreState: string }

/** The version the store lets us edit — the one a release is preparing. */
export const editableVersion = async () => {
  const versions = await api<Collection<Version>>(
    `/v1/apps/${await appId()}/appStoreVersions?limit=10`,
  )
  // Anything but these states is a version already handed to Apple, whose
  // screenshots are frozen; failing here beats uploading into a void.
  const editable = ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED']
  const version = versions.data.find((v) => editable.includes(v.attributes.appStoreState))
  if (!version)
    throw new Error(
      `No editable version: ${versions.data
        .map((v) => `${v.attributes.versionString} is ${v.attributes.appStoreState}`)
        .join(', ')}`,
    )
  return version
}
