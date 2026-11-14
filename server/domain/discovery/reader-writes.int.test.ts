import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { DiscoveryCommand } = await import('~/domain/discovery/command')
const { AwaitedEditionCommand } = await import('~/domain/awaited-edition/command')

const reader = 'reader-1' as UserId
const now = new Date('2026-11-14T08:00:00.000Z')

const stored = () => fake.data('discovery-readers', reader)

// A pass reads every reader at its start and writes each back minutes later,
// while the tab, the alerts and the digest write the same document. Each writer
// changes its own fields on the document as it stands, never the pass's copy.
const seedReader = (fields: Record<string, unknown> = {}) =>
  fake.seed('discovery-readers', reader, {
    userId: reader,
    language: 'fr',
    sagas: [{ seriesId: 'carl', language: 'fr', name: 'Dungeon Crawler Carl' }],
    syncedAt: now,
    notified: [],
    ...fields,
  })

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('the alerts sent to a reader', () => {
  test('add to the keys another pass stored meanwhile', async () => {
    seedReader({ notified: ['carl--fr--6'] })

    await DiscoveryCommand.markNotified(reader, ['carl--fr--7'])

    expect(stored()?.notified).toEqual(['carl--fr--6', 'carl--fr--7'])
  })

  test('leave the sagas the tab wrote meanwhile', async () => {
    seedReader({ sagas: [] })

    await DiscoveryCommand.markNotified(reader, ['carl--fr--7'])

    expect(stored()?.sagas).toHaveLength(0)
    expect(stored()?.notified).toEqual(['carl--fr--7'])
  })

  test('never bring back a reader deleted meanwhile', async () => {
    expect(await DiscoveryCommand.markNotified(reader, ['carl--fr--7'])).toBeUndefined()

    expect(stored()).toBeNull()
  })
})

describe('the digest sent to a reader', () => {
  test('keeps the alerts pushed meanwhile', async () => {
    seedReader({ notified: ['carl--fr--7'], announced: ['carl--fr--5'] })

    await DiscoveryCommand.markAnnounced(reader, ['carl--fr--6'])

    expect(stored()?.notified).toEqual(['carl--fr--7'])
    expect(stored()?.announced).toEqual(['carl--fr--5', 'carl--fr--6'])
  })
})

describe('the library remembered for a reader', () => {
  test('starts a new reader with no alert sent', async () => {
    await DiscoveryCommand.rememberLibrary(
      { userId: reader, language: 'fr', sagas: [], authors: [], narrators: [], syncedAt: now },
      undefined,
    )

    expect(stored()).toMatchObject({ language: 'fr', notified: [] })
  })

  test('keeps the alerts and digests stored meanwhile', async () => {
    // What the tab read when it opened, before a pass recorded the alerts.
    const known = { userId: reader, language: 'fr', sagas: [], syncedAt: now, notified: [] }
    seedReader({ notified: ['carl--fr--7'], announced: ['carl--fr--6'] })

    await DiscoveryCommand.rememberLibrary(
      { userId: reader, language: 'en', sagas: [], authors: [], narrators: [], syncedAt: now },
      known as never,
    )

    expect(stored()).toMatchObject({
      language: 'en',
      sagas: [],
      notified: ['carl--fr--7'],
      announced: ['carl--fr--6'],
    })
  })
})

describe('the alert of an awaited edition', () => {
  const awaited = {
    id: 'reader-1~edition',
    userId: reader,
    format: 'book',
    language: 'fr',
    source: { title: 'Le Nom du vent' },
    watchKey: 'edition',
    awaitedAt: now,
  }

  test('is stamped on the edition as it stands', async () => {
    fake.seed('awaited-editions', awaited.id, { ...awaited, language: 'en' })

    await AwaitedEditionCommand.markNotified(awaited as never, now)

    expect(fake.data('awaited-editions', awaited.id)).toMatchObject({ language: 'en' })
    expect(fake.data('awaited-editions', awaited.id)?.notifiedAt).toEqual(now)
  })

  test('never brings back an edition the reader stopped awaiting meanwhile', async () => {
    expect(await AwaitedEditionCommand.markNotified(awaited as never, now)).toBeUndefined()

    expect(fake.data('awaited-editions', awaited.id)).toBeNull()
  })
})
