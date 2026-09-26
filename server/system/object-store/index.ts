import { mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { getStorage } from 'firebase-admin/storage'
import { config } from '~/system/config'
// Side-effect import: the admin app must be initialized before getStorage().
import '~/system/firebase'
import { ByteSize, ContentType, ObjectPath, SignedUrl } from '~/system/object-store/primitives'
import { DOWNLOAD_WINDOW_MS, reusingSignatures } from '~/system/object-store/signatures'
import type {
  ContentType as ContentTypeValue,
  ObjectPath as ObjectPathValue,
  SignedUrl as SignedUrlValue,
  StoredObject,
} from '~/system/object-store/types'

// Where the cover bytes go. The bucket is private and its objects are never
// public: every read goes through a URL this server signed, for one object, for
// one hour. Nothing else can reach them.
//
// There is no signed *upload* URL here, unlike Vinarium. A cover arrives inside
// the scan mutation, so the server already holds the bytes and writes them
// itself — the three-step reserve/upload/confirm dance would buy nothing and
// leaves orphans to sweep.
export type ObjectStore = {
  write: (
    path: ObjectPathValue,
    body: Buffer,
    contentType: ContentTypeValue,
  ) => Promise<StoredObject>
  downloadUrl: (path: ObjectPathValue) => Promise<SignedUrlValue>
  stat: (path: ObjectPathValue) => Promise<StoredObject | null>
  remove: (path: ObjectPathValue) => Promise<void>
  removeByPrefix: (prefix: ObjectPathValue) => Promise<void>
}

const bucket = () => {
  const name = config().attachmentsBucket
  if (!name) throw new Error('NITRO_ATTACHMENTS_BUCKET is unset — covers have nowhere to go')
  return getStorage().bucket(name)
}

// Signing without a private key on disk goes through the IAM signBlob API, so
// the runtime service account needs roles/iam.serviceAccountTokenCreator on
// itself (see infra/storage.tf). Without it every signature fails in production
// while local credentials keep working — the failure mode this comment exists for.
const gcs: ObjectStore = {
  write: async (path, body, contentType) => {
    await bucket().file(path).save(body, { contentType, resumable: false })
    return { contentType, size: ByteSize(body.byteLength) }
  },
  downloadUrl: reusingSignatures(async (path) => {
    const [url] = await bucket()
      .file(path)
      .getSignedUrl({
        version: 'v4',
        action: 'read',
        expires: Date.now() + DOWNLOAD_WINDOW_MS,
      })
    return SignedUrl(url)
  }),
  stat: async (path) => {
    const file = bucket().file(path)
    const [exists] = await file.exists()
    if (!exists) return null
    const [metadata] = await file.getMetadata()
    return {
      contentType: ContentType(metadata.contentType ?? 'application/octet-stream'),
      size: ByteSize(Number(metadata.size ?? 0)),
    }
  },
  remove: async (path) => {
    await bucket().file(path).delete({ ignoreNotFound: true })
  },
  removeByPrefix: async (prefix) => {
    await bucket().deleteFiles({ prefix, force: true })
  },
}

// The development stand-in. The Storage emulator cannot sign a V4 URL, and
// `scripts/e2e.sh` gates every release on a local stack, so the local store keeps
// the bytes on disk and points at the dev-only route under /dev/storage. Both it
// and that route are compiled out of a production bundle.
const LOCAL_ROOT = '.data/covers'
const localFile = (path: ObjectPathValue) => join(LOCAL_ROOT, path)
const localUrl = (path: ObjectPathValue) =>
  SignedUrl(`${config().publicBaseUrl}/dev/storage/${path}`)

const local: ObjectStore = {
  write: async (path, body, contentType) => {
    await mkdir(dirname(localFile(path)), { recursive: true })
    await writeFile(localFile(path), body)
    await writeFile(`${localFile(path)}.type`, contentType)
    return { contentType, size: ByteSize(body.byteLength) }
  },
  downloadUrl: async (path) => localUrl(path),
  stat: async (path) => {
    try {
      const [bytes, contentType] = await Promise.all([
        readFile(localFile(path)),
        readFile(`${localFile(path)}.type`, 'utf8'),
      ])
      return { contentType: ContentType(contentType), size: ByteSize(bytes.byteLength) }
    } catch {
      return null
    }
  },
  remove: async (path) => {
    await rm(localFile(path), { force: true })
    await rm(`${localFile(path)}.type`, { force: true })
  },
  removeByPrefix: async (prefix) => {
    await rm(localFile(prefix), { force: true, recursive: true })
  },
}

export const objectStore = (): ObjectStore => (import.meta.dev ? local : gcs)

/** Used by the dev-only download route to serve what `local` wrote. */
export const readLocalObject = async (path: ObjectPathValue) => {
  const [body, contentType] = await Promise.all([
    readFile(localFile(path)),
    readFile(`${localFile(path)}.type`, 'utf8'),
  ])
  return { body, contentType }
}

export { ObjectPath }
