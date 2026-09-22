import { NotificationCommand } from '~/domain/notification/command'
import {
  AlertKindEnum,
  PushEnvironmentEnum,
} from '~/domain/notification/infrastructure/graphql/enums'
import { NotificationSettingsType } from '~/domain/notification/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'

builder.mutationFields((t) => ({
  registerDevice: t.field({
    type: NotificationSettingsType,
    description:
      'Remember a device to push alerts to. The app calls it on every launch ' +
      'with notifications allowed, so a token APNs rotated is picked up; ' +
      'registering the same token again only refreshes it.',
    args: {
      token: t.arg({ type: 'DeviceToken', required: true }),
      environment: t.arg({ type: PushEnvironmentEnum, required: true }),
    },
    resolve: (_root, args, context) =>
      NotificationCommand.registerDevice(context.userId, args.token, args.environment),
  }),

  unregisterDevice: t.field({
    type: NotificationSettingsType,
    description: 'Forget a device, when the reader signs out of it.',
    args: { token: t.arg({ type: 'DeviceToken', required: true }) },
    resolve: (_root, args, context) =>
      NotificationCommand.forgetDevices(context.userId, [args.token]),
  }),

  setAlert: t.field({
    type: NotificationSettingsType,
    description: 'Switch one alert on or off.',
    args: {
      kind: t.arg({ type: AlertKindEnum, required: true }),
      enabled: t.arg.boolean({ required: true }),
    },
    resolve: (_root, args, context) =>
      NotificationCommand.setAlert(context.userId, args.kind, args.enabled),
  }),
}))
