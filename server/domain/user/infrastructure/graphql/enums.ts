import { builder } from '~/domain/shared/graphql/builder'
import { AVATAR_HEROES } from '~/domain/user/types'

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
