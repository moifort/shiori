import { emptySettings } from '~/domain/notification/business-rules'
import * as repository from '~/domain/notification/infrastructure/repository'
import type { NotificationSettings } from '~/domain/notification/types'
import type { UserId } from '~/domain/shared/types'

export namespace NotificationQuery {
  /** The reader's settings, every alert off when they never touched them. */
  export const settings = async (userId: UserId, now = new Date()): Promise<NotificationSettings> =>
    (await repository.findByUser(userId)) ?? emptySettings(userId, now)
}
