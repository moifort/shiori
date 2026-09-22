import { withAlert, withDevice, withoutDevices } from '~/domain/notification/business-rules'
import * as repository from '~/domain/notification/infrastructure/repository'
import { NotificationQuery } from '~/domain/notification/query'
import type { AlertKind, DeviceToken, NotificationSettings } from '~/domain/notification/types'
import type { UserId } from '~/domain/shared/types'
import type { PushEnvironment } from '~/system/apns'

export namespace NotificationCommand {
  /** Remember where to reach the reader. Called by the app on every launch with
   *  notifications allowed, so a token APNs rotated is picked up. */
  export const registerDevice = async (
    userId: UserId,
    token: DeviceToken,
    environment: PushEnvironment,
    now = new Date(),
  ): Promise<NotificationSettings> =>
    repository.save(
      withDevice(await NotificationQuery.settings(userId, now), token, environment, now),
    )

  /** Forget a device: the reader signed out of it, or APNs said it is gone. */
  export const forgetDevices = async (
    userId: UserId,
    tokens: readonly DeviceToken[],
    now = new Date(),
  ): Promise<NotificationSettings> =>
    repository.save(withoutDevices(await NotificationQuery.settings(userId, now), tokens, now))

  export const setAlert = async (
    userId: UserId,
    kind: AlertKind,
    enabled: boolean,
    now = new Date(),
  ): Promise<NotificationSettings> =>
    repository.save(withAlert(await NotificationQuery.settings(userId, now), kind, enabled, now))

  export const deleteForUser = async (userId: UserId): Promise<void> => repository.remove(userId)
}
