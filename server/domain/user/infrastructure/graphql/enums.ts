import { builder } from '~/domain/shared/graphql/builder'
import { AVATAR_HEROES } from '~/domain/user/types'

export const AvatarHeroEnum = builder.enumType('AvatarHero', {
  description:
    'A hero of a classic novel a reader may wear as an avatar.\n\n' +
    'The portraits are drawn for the app and bundled in it; the server keeps only ' +
    'the name. Every hero comes from a book in the public domain.',
  values: Object.fromEntries(
    AVATAR_HEROES.map((hero) => [
      hero.replace(/([A-Z])/g, '_$1').toUpperCase(),
      { value: hero, description: `The portrait of \`${hero}\`.` },
    ]),
  ) as Record<string, { value: (typeof AVATAR_HEROES)[number]; description: string }>,
})
