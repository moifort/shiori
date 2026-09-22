import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import type { PushOutcome } from '~/system/apns'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const sent: { token: string; title: string }[] = []
let answer: PushOutcome = 'sent'
mock.module('~/system/apns', () => ({
  Apns: {
    send: async (device: { token: string }, message: { title: string }) => {
      sent.push({ token: device.token, title: message.title })
      return answer
    },
  },
}))

const { NotificationCommand } = await import('~/domain/notification/command')
const { NotificationQuery } = await import('~/domain/notification/query')
const { NotificationUseCase } = await import('~/domain/notification/use-case')
const { DeviceToken } = await import('~/domain/notification/primitives')

const reader = 'reader' as UserId
const phone = DeviceToken('a'.repeat(64))
const alert = {
  kind: 'series-volume' as const,
  title: 'Stormlight, tome 6',
  body: 'Sort le 14 octobre.',
}

beforeEach(() => {
  resetFakeFirestore()
  sent.length = 0
  answer = 'sent'
})

describe('pushing an alert', () => {
  test('reaches every device of a reader who switched the alert on', async () => {
    await NotificationCommand.registerDevice(reader, phone, 'production')
    await NotificationCommand.setAlert(reader, 'series-volume', true)

    expect(await NotificationUseCase.notify(reader, alert)).toBe(true)
    expect(sent).toEqual([{ token: phone, title: 'Stormlight, tome 6' }])
  })

  test('stays silent for an alert the reader left off', async () => {
    await NotificationCommand.registerDevice(reader, phone, 'production')

    expect(await NotificationUseCase.notify(reader, alert)).toBe(false)
    expect(sent).toEqual([])
  })

  test('forgets a device APNs says is gone', async () => {
    await NotificationCommand.registerDevice(reader, phone, 'production')
    await NotificationCommand.setAlert(reader, 'series-volume', true)
    answer = 'unregistered'

    await NotificationUseCase.notify(reader, alert)

    expect((await NotificationQuery.settings(reader)).devices).toEqual([])
  })
})
