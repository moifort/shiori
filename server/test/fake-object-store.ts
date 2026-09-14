import { mock } from 'bun:test'
import type { ObjectStore } from '~/domain/attachment/infrastructure/object-store'
import type { ObjectPath, SignedUrl, StoredObject } from '~/domain/attachment/types'

/** Cloud Storage, as a map. The real store reads `useRuntimeConfig()`, a Nitro
 *  global that does not exist under `bun test`, so any test whose code path
 *  reaches an attachment has to stand this in — the same way every test that
 *  touches Firestore stands in the fake database.
 *
 *  Deleting a beverage or an account now walks through here, which is why it
 *  lives in `test/` rather than in one domain's test file: three use cases need
 *  it, and a mock installed by one file leaking into another is how a suite
 *  starts passing for reasons nobody chose. */
export const createFakeObjectStore = () => {
  const objects = new Map<string, StoredObject & { storedAt: Date }>()
  const removed: string[] = []

  const store: ObjectStore = {
    uploadUrl: async (path) => `https://upload.test/${path}` as SignedUrl,
    downloadUrl: async (path) => `https://download.test/${path}` as SignedUrl,
    stat: async (path) => objects.get(path) ?? null,
    remove: async (path) => {
      removed.push(path)
      objects.delete(path)
    },
    removeByPrefix: async (prefix) => {
      for (const path of [...objects.keys()]) if (path.startsWith(prefix)) objects.delete(path)
      removed.push(`${prefix}*`)
    },
    list: async (prefix) =>
      [...objects.entries()]
        .filter(([path]) => path.startsWith(prefix))
        .map(([path, { storedAt }]) => ({ path: path as ObjectPath, storedAt })),
  }

  return {
    store,
    objects,
    removed,
    put: (path: string, object: Partial<StoredObject & { storedAt: Date }> = {}) =>
      objects.set(path, {
        contentType: 'image/jpeg' as StoredObject['contentType'],
        size: 1_000_000 as StoredObject['size'],
        storedAt: new Date(),
        ...object,
      }),
    reset: () => {
      objects.clear()
      removed.length = 0
    },
  }
}

/** Installs the module mock and hands back the fake. Call at the top level of a
 *  test file, next to the `mock.module` for Firestore. */
export const mockObjectStore = () => {
  const fake = createFakeObjectStore()
  mock.module('~/domain/attachment/infrastructure/object-store', () => ({
    objectStore: () => fake.store,
  }))
  return fake
}
