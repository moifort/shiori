import { wantsAlert } from '~/domain/notification/business-rules'
import { NotificationCommand } from '~/domain/notification/command'
import * as repository from '~/domain/notification/infrastructure/repository'
import type { Alert } from '~/domain/notification/types'
import type { UserId } from '~/domain/shared/types'
import { Apns } from '~/system/apns'

export namespace NotificationUseCase {
  /** Push an alert to every device of the reader, if they switched its kind
   *  on. Devices APNs reports gone are forgotten on the way. Answers whether
   *  the alert reached at least one device — or would have, on a server with
   *  no APNs key, where it is only logged. */
  export const notify = async (userId: UserId, alert: Alert): Promise<boolean> => {
    const settings = await repository.findByUser(userId)
    if (!settings || !wantsAlert(settings, alert.kind)) return false
    const outcomes = await Promise.all(
      settings.devices.map(async (device) => ({
        device,
        outcome: await Apns.send(device, {
          title: alert.title,
          body: alert.body,
          threadId: alert.kind,
          link: alert.link,
        }),
      })),
    )
    const gone = outcomes.filter(({ outcome }) => outcome === 'unregistered')
    if (gone.length > 0)
      await NotificationCommand.forgetDevices(
        userId,
        gone.map(({ device }) => device.token),
      )
    return outcomes.some(({ outcome }) => outcome === 'sent' || outcome === 'unconfigured')
  }
}
