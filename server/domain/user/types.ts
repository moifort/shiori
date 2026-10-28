import type { PersonName, UserId } from '~/domain/shared/types'
import type { ObjectPath } from '~/system/object-store/types'

// The heroes a reader may wear as an avatar, drawn for the app and bundled in
// it: the server keeps only the name. Every one comes from a book in the public
// domain, so no estate owns the face.
export const AVATAR_HEROES = [
  'alice',
  'dorothy',
  'merlin',
  'dracula',
  'nemo',
  'creature',
  'timeTraveller',
  'invisibleMan',
  'holmes',
  'lupin',
  'dupin',
  'rouletabille',
] as const
export type AvatarHero = (typeof AVATAR_HEROES)[number]

// What stands for the reader beside their name: a hero, or a photo of their
// own kept in the private bucket. No avatar at all draws their initials.
export type Avatar = { kind: 'hero'; hero: AvatarHero } | { kind: 'photo'; path: ObjectPath }

// A user's profile, written once the onboarding wizard completes. The doc id IS
// the userId, so a user has at most one profile. `admin` opens the in-app admin
// screen; it is only ever set by hand in the Firestore console, never by code.
export type UserProfile = {
  userId: UserId
  firstName: PersonName
  onboardingCompletedAt: Date
  admin?: boolean
  avatar?: Avatar
}

// The signed-in user's identity and onboarding state — every field but the id is
// optional so the app can route to onboarding when no profile exists yet.
export type MeView = {
  userId: UserId
  firstName?: PersonName
  onboardingCompletedAt?: Date
  admin: boolean
  avatar?: Avatar
}
