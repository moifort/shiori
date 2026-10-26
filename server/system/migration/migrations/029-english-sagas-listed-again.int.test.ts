import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { englishSagasListedAgain } = await import(
  '~/system/migration/migrations/029-english-sagas-listed-again'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const volume = (number: number, extra: Record<string, unknown> = {}) => ({
  number,
  title: `Volume ${number}`,
  ...extra,
})

describe('English sagas listed again', () => {
  test('lose their mark when Audible answered for none of their volumes', async () => {
    fake.seed('saga-watches', 'kings-of-sin--en', {
      key: 'kings-of-sin--en',
      language: 'en',
      volumes: [volume(1), volume(2)],
      audibleListed: true,
    })
    fake.seed('saga-watches', 'bridge-kingdom--en', {
      key: 'bridge-kingdom--en',
      language: 'en',
      volumes: [],
      audibleListed: true,
    })
    // Listed for real: its volumes carry the recordings Audible answered for.
    fake.seed('saga-watches', 'throne-of-glass--en', {
      key: 'throne-of-glass--en',
      language: 'en',
      volumes: [volume(1, { asin: 'B08T21NXQ9' })],
      audibleListed: true,
    })
    // The French store was always the one asked.
    fake.seed('saga-watches', 'chronique--fr', {
      key: 'chronique--fr',
      language: 'fr',
      volumes: [volume(1)],
      audibleListed: true,
    })

    const result = await englishSagasListedAgain.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 2 })
    expect(fake.data('saga-watches', 'kings-of-sin--en')).toEqual({
      key: 'kings-of-sin--en',
      language: 'en',
      volumes: [volume(1), volume(2)],
    })
    expect(fake.data('saga-watches', 'bridge-kingdom--en')?.audibleListed).toBeUndefined()
    expect(fake.data('saga-watches', 'throne-of-glass--en')?.audibleListed).toBe(true)
    expect(fake.data('saga-watches', 'chronique--fr')?.audibleListed).toBe(true)
  })
})
