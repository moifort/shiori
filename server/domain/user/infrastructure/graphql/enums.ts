import { builder } from '~/domain/shared/graphql/builder'
import { AVATAR_COLORS, AVATAR_HEROES, type HOME_PROMPTS } from '~/domain/user/types'

export const AvatarHeroEnum = builder.enumType('AvatarHero', {
  description:
    'A hero of a classic novel a reader may wear as an avatar.\n\n' +
    'The portraits are drawn for the app and bundled in it; the server keeps only ' +
    'the name. Classics of the public domain sit beside characters of recent books. ' +
    'A build that does not know a newer hero draws the initials instead.',
  values: Object.fromEntries(
    AVATAR_HEROES.map((hero) => [
      hero.replace(/([A-Z])/g, '_$1').toUpperCase(),
      { value: hero, description: `The portrait of \`${hero}\`.` },
    ]),
  ) as Record<string, { value: (typeof AVATAR_HEROES)[number]; description: string }>,
})

export const AvatarColorEnum = builder.enumType('AvatarColor', {
  description:
    'A background the reader’s initials may be drawn on. The default slate is not ' +
    'one: it is no avatar at all. A build that does not know a colour draws slate.',
  values: Object.fromEntries(
    AVATAR_COLORS.map((color) => [
      color.toUpperCase(),
      { value: color, description: `Initials on ${color}.` },
    ]),
  ) as Record<string, { value: (typeof AVATAR_COLORS)[number]; description: string }>,
})

export const HomePromptEnum = builder.enumType('HomePrompt', {
  description:
    'Something the home screen’s hero asks the reader to set up, until it is done or ' +
    'they turn it down. A build that does not know a newer prompt leaves it out.',
  values: {
    AUDIBLE: { value: 'audible', description: 'Connect the Audible library.' },
    KINDLE: { value: 'kindle', description: 'Connect the Kindle library.' },
    FRIENDS: { value: 'friends', description: 'Invite a first friend.' },
  } satisfies Record<string, { value: (typeof HOME_PROMPTS)[number]; description: string }>,
})
