import { describe, expect, test } from 'bun:test'
import {
  DEVICES_KEPT,
  emptySettings,
  wantsAlert,
  withAlert,
  withDevice,
  withoutDevices,
} from '~/domain/notification/business-rules'
import { DeviceToken } from '~/domain/notification/primitives'
import type { UserId } from '~/domain/shared/types'

const now = new Date('2026-09-22T10:00:00Z')
const reader = 'reader' as UserId
const token = (digit: string) => DeviceToken(digit.repeat(64))

describe('the devices a reader is reached on', () => {
  test('registering a device twice keeps it once, moved to the front', () => {
    const once = withDevice(emptySettings(reader, now), token('a'), 'production', now)
    const twice = withDevice(
      withDevice(once, token('b'), 'sandbox', now),
      token('a'),
      'production',
      now,
    )

    expect(twice.devices.map((device) => device.token)).toEqual([token('a'), token('b')])
  })

  test('keeps the most recent few, dropping the oldest', () => {
    let settings = emptySettings(reader, now)
    for (const digit of '0123456789'.slice(0, DEVICES_KEPT + 1))
      settings = withDevice(settings, token(digit), 'production', now)

    expect(settings.devices).toHaveLength(DEVICES_KEPT)
    expect(settings.devices.map((device) => device.token)).not.toContain(token('0'))
  })

  test('forgets the devices APNs reported gone', () => {
    const settings = withDevice(
      withDevice(emptySettings(reader, now), token('a'), 'production', now),
      token('b'),
      'production',
      now,
    )

    expect(withoutDevices(settings, [token('a')], now).devices.map((d) => d.token)).toEqual([
      token('b'),
    ])
  })

  test('reads tokens in either case as one', () => {
    expect(DeviceToken('AB'.repeat(32))).toBe(DeviceToken('ab'.repeat(32)))
    expect(() => DeviceToken('not a token')).toThrow()
  })
})

describe('whether an alert goes out', () => {
  const reachable = withDevice(emptySettings(reader, now), token('a'), 'production', now)

  test('by default, until the reader switches it off', () => {
    expect(wantsAlert(reachable, 'translation')).toBe(true)
    expect(wantsAlert(withAlert(reachable, 'translation', false, now), 'translation')).toBe(false)
  })

  test('never without a device to send it to', () => {
    expect(wantsAlert(emptySettings(reader, now), 'translation')).toBe(false)
    expect(wantsAlert(undefined, 'translation')).toBe(false)
  })

  test('switching an alert on twice keeps it once', () => {
    const twice = withAlert(
      withAlert(reachable, 'translation', true, now),
      'translation',
      true,
      now,
    )

    expect(twice.alerts).toEqual(['translation'])
  })
})
