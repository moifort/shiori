import type { PushEnvironment } from '~/system/apns'
import { ALERT_KINDS, type AlertKind, type DeviceToken, type NotificationSettings } from './types'

/** A reader signs in on a phone, an iPad, a new phone: a handful of devices,
 *  never more. The oldest goes when a new one arrives past the limit, since a
 *  device that stopped registering is one that stopped existing. */
export const DEVICES_KEPT = 5

export const emptySettings = (
  userId: NotificationSettings['userId'],
  now: Date,
): NotificationSettings => ({
  userId,
  devices: [],
  alerts: [...ALERT_KINDS],
  updatedAt: now,
})

/** Remember a device, once: registering again refreshes it and moves it to
 *  the front. */
export const withDevice = (
  settings: NotificationSettings,
  token: DeviceToken,
  environment: PushEnvironment,
  now: Date,
): NotificationSettings => ({
  ...settings,
  devices: [
    { token, environment, registeredAt: now },
    ...settings.devices.filter((device) => device.token !== token),
  ].slice(0, DEVICES_KEPT),
  updatedAt: now,
})

export const withoutDevices = (
  settings: NotificationSettings,
  tokens: readonly DeviceToken[],
  now: Date,
): NotificationSettings => ({
  ...settings,
  devices: settings.devices.filter((device) => !tokens.includes(device.token)),
  updatedAt: now,
})

export const withAlert = (
  settings: NotificationSettings,
  kind: AlertKind,
  enabled: boolean,
  now: Date,
): NotificationSettings => ({
  ...settings,
  alerts: enabled
    ? [...new Set([...settings.alerts, kind])]
    : settings.alerts.filter((alert) => alert !== kind),
  updatedAt: now,
})

/** Whether an alert of this kind should reach the reader at all. */
export const wantsAlert = (settings: NotificationSettings | undefined, kind: AlertKind): boolean =>
  settings !== undefined && settings.devices.length > 0 && settings.alerts.includes(kind)
