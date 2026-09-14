import type { PersonName, UserId } from '~/domain/shared/types'

// A user's profile, written once the onboarding wizard completes. The doc id IS
// the userId, so a user has at most one profile. `admin` opens the in-app admin
// screen; it is only ever set by hand in the Firestore console, never by code.
export type UserProfile = {
  userId: UserId
  firstName: PersonName
  onboardingCompletedAt: Date
  admin?: boolean
}

// The signed-in user's identity and onboarding state — every field but the id is
// optional so the app can route to onboarding when no profile exists yet.
export type MeView = {
  userId: UserId
  firstName?: PersonName
  onboardingCompletedAt?: Date
  admin: boolean
}
