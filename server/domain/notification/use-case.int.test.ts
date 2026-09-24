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
  kind: 'translation' as const,
  title: 'Enfin traduit',
  body: '« Projet Dernière Chance » est disponible en français.',
}

beforeEach(() => {
  resetFakeFirestore()
  sent.length = 0
  answer = 'sent'
})

describe('pushing an alert', () => {
  test('reaches every device of a reader, the alert being on by default', async () => {
    await NotificationCommand.registerDevice(reader, phone, 'production')

    expect(await NotificationUseCase.notify(reader, alert)).toBe(true)
    expect(sent).toEqual([{ token: phone, title: 'Enfin traduit' }])
  })

  test('stays silent for an alert the reader switched off', async () => {
    await NotificationCommand.registerDevice(reader, phone, 'production')
    await NotificationCommand.setAlert(reader, 'translation', false)

    expect(await NotificationUseCase.notify(reader, alert)).toBe(false)
    expect(sent).toEqual([])
  })

  test('forgets a device APNs says is gone', async () => {
    await NotificationCommand.registerDevice(reader, phone, 'production')
    answer = 'unregistered'

    await NotificationUseCase.notify(reader, alert)

    expect((await NotificationQuery.settings(reader)).devices).toEqual([])
  })
})
