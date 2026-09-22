import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { FriendshipCommand } = await import('~/domain/friendship/command')

const reader = 'reader-1' as UserId
const DAY_MS = 86_400_000
const NOW = new Date('2026-09-22T10:00:00.000Z')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('inviting a friend', () => {
  test('hands out the invitation still standing', async () => {
    const first = await FriendshipCommand.invite(reader, NOW)

    expect(await FriendshipCommand.invite(reader, new Date(NOW.getTime() + DAY_MS))).toEqual(first)
  })

  // Nothing reads a lapsed invitation again, and each one left behind would
  // add a read to every later invitation.
  test('sweeps the lapsed invitations when it writes a fresh one', async () => {
    const lapsed = await FriendshipCommand.invite(reader, NOW)

    const fresh = await FriendshipCommand.invite(reader, new Date(NOW.getTime() + 30 * DAY_MS))

    expect(fresh.code).not.toBe(lapsed.code)
    expect(fake.data('friend-invitations', lapsed.code)).toBeNull()
    expect(fake.data('friend-invitations', fresh.code)).not.toBeNull()
  })
})
