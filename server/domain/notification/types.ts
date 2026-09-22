import type { Brand } from 'ts-brand'
import type { UserId } from '~/domain/shared/types'
import type { PushEnvironment } from '~/system/apns'

/** The alerts a reader can switch on, one switch each. Every one of them is
 *  about a book coming out: Shiori never pushes to bring a reader back. */
export const ALERT_KINDS = [
  /** A new volume of a saga the reader follows. */
  'series-volume',
  /** The French translation of a book the reader read in English. */
  'translation',
  /** A new Audible recording in a saga the reader follows. */
  'audible-release',
  /** A new book by an author the reader hearted or rated five stars. */
  'author-release',
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
 *  about. Every alert starts switched off — the permission is asked the first
 *  time the reader turns one on, never at launch. */
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
