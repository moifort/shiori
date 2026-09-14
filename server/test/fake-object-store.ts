import type { ObjectStore } from '~/system/object-store'
import { ByteSize, ContentType, SignedUrl } from '~/system/object-store/primitives'
import type { ObjectPath, StoredObject } from '~/system/object-store/types'

/** In-memory object store for the integration tests. Holds what was written so a
 *  test can assert the bytes reached the bucket, without a bucket. */
export const fakeObjectStore = () => {
  const objects = new Map<string, { body: Buffer } & StoredObject>()

  const store: ObjectStore = {
    write: async (path, body, contentType) => {
      const stored = { body, contentType, size: ByteSize(body.byteLength) }
      objects.set(path, stored)
      return { contentType: stored.contentType, size: stored.size }
    },
    downloadUrl: async (path) => SignedUrl(`https://fake.store/${path}`),
    stat: async (path) => {
      const stored = objects.get(path)
      return stored ? { contentType: stored.contentType, size: stored.size } : null
    },
    remove: async (path) => {
      objects.delete(path)
    },
    removeByPrefix: async (prefix) => {
      for (const path of [...objects.keys()]) if (path.startsWith(prefix)) objects.delete(path)
    },
  }

  return {
    store,
    bodyOf: (path: ObjectPath) => objects.get(path)?.body ?? null,
    contentTypeOf: (path: ObjectPath) => objects.get(path)?.contentType ?? null,
    count: () => objects.size,
    seed: (path: ObjectPath, body: Buffer, contentType = 'image/jpeg') => {
      objects.set(path, {
        body,
        contentType: ContentType(contentType),
        size: ByteSize(body.byteLength),
      })
    },
  }
}
