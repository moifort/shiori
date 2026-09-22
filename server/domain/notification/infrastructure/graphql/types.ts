import { AlertKindEnum } from '~/domain/notification/infrastructure/graphql/enums'
import { ALERT_KINDS, type NotificationSettings } from '~/domain/notification/types'
import { builder } from '~/domain/shared/graphql/builder'

const AlertSwitchType = builder
  .objectRef<{ kind: (typeof ALERT_KINDS)[number]; enabled: boolean }>('AlertSwitch')
  .implement({
    description: 'One alert and whether the reader switched it on.',
    fields: (t) => ({
      kind: t.field({ type: AlertKindEnum, resolve: (entry) => entry.kind }),
      enabled: t.exposeBoolean('enabled'),
    }),
  })

export const NotificationSettingsType = builder
  .objectRef<NotificationSettings>('NotificationSettings')
  .implement({
    description:
      'What the reader wants to hear about, and whether any device can hear it. ' +
      'Every alert starts switched off.',
    fields: (t) => ({
      alerts: t.field({
        type: [AlertSwitchType],
        description: 'Every alert there is, in a fixed order, each with its switch.',
        resolve: (settings) =>
          ALERT_KINDS.map((kind) => ({ kind, enabled: settings.alerts.includes(kind) })),
      }),
      deviceCount: t.int({
        description: 'How many devices are registered to receive them.',
        resolve: (settings) => settings.devices.length,
      }),
    }),
  })
