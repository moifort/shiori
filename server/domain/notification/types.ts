import type { Brand } from 'ts-brand'
import type { UserId } from '~/domain/shared/types'
import type { PushEnvironment } from '~/system/apns'

/** The alerts a reader can switch off, one switch each. Every one of them is
 *  about a book coming out: Shiori never pushes to bring a reader back. */
export const ALERT_KINDS = [
  /** A new volume of a saga the reader follows. Named for what it first
   *  announced; the stored value stays, since renaming it costs a migration. */
  'translation',
] as const
export type AlertKind = (typeof ALERT_KINDS)[number]

/** The token APNs hands a device for this app, in hexadecimal. */
export type DeviceToken = Brand<string, 'DeviceToken'>

export type Device = {
  token: DeviceToken
  environment: PushEnvironment
  registeredAt: Date
}

/** One document per reader: where to reach them and what they want to hear
 *  about. Every alert starts switched on — it only announces volumes of sagas
 *  the reader follows — and the permission is asked the first
 *  time the tab has a release to announce, never at launch. */
export type NotificationSettings = {
  userId: UserId
  devices: Device[]
  alerts: AlertKind[]
  updatedAt: Date
}

/** A notification as the release tracker asks for it. */
export type Alert = {
  kind: AlertKind
  title: string
  body: string
  /** Where tapping it opens, as a `shiori://` link. */
  link?: string
}
