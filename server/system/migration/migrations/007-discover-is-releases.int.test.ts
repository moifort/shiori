import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { discoverIsReleases } = await import(
  '~/system/migration/migrations/007-discover-is-releases'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => discoverIsReleases.migrate({ db: fakeDb() })

describe('turning Découvrir into releases', () => {
  test('drops the shared translation watches', async () => {
    fake.seed('translation-watches', 'series--carl--x--fr', { editions: [] })
    fake.seed('series', 'carl--x', { id: 'carl--x', volumes: [] })

    await run()

    expect(fake.data('translation-watches', 'series--carl--x--fr')).toBeNull()
    expect(fake.data('series', 'carl--x')).not.toBeNull()
  })

  test('names the language of what a reader set aside and was told of', async () => {
    fake.seed('discover', 'reader', {
      userId: 'reader',
      language: 'fr',
      dismissed: ['series--carl--matt-dinniman', 'book--project-hail-mary--andy-weir'],
      notified: [
        'series--carl--matt-dinniman--audiobook--4',
        'book--project-hail-mary--andy-weir--book--project-hail-mary',
      ],
      dated: [{ key: 'series--carl--matt-dinniman--book--4' }],
    })

    const result = await run()

    expect(result).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('discover', 'reader')).toMatchObject({
      dismissed: ['series--carl--matt-dinniman--fr', 'book--project-hail-mary--andy-weir--fr'],
      notified: [
        'series--carl--matt-dinniman--fr--audiobook--4',
        'book--project-hail-mary--andy-weir--fr--book--project-hail-mary',
      ],
      dated: [],
    })
  })
})
