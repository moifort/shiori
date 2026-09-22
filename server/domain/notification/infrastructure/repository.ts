import type { NotificationSettings } from '~/domain/notification/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// One document per reader, keyed by the reader, in a flat top-level collection.
const settings = () =>
  db()
    .collection('notification-settings')
    .withConverter(genericDataConverter<NotificationSettings>())

export const findByUser = async (userId: UserId): Promise<NotificationSettings | undefined> =>
  (await settings().doc(userId).get()).data()

export const save = async (value: NotificationSettings): Promise<NotificationSettings> => {
  await settings().doc(value.userId).set(withoutAbsentFields(value))
  return value
}

export const remove = async (userId: UserId): Promise<void> => {
  await settings().doc(userId).delete()
}
