import type { WriteBatch } from 'firebase-admin/firestore'
import type { PersonName, UserId } from '~/domain/shared/types'
import * as repository from '~/domain/user/infrastructure/repository'
import type { Avatar, UserProfile } from '~/domain/user/types'

export namespace UserCommand {
  // Persist the profile that marks onboarding done. The welcome scans are
  // granted separately by UserUseCase.completeOnboarding, in the same batch.
  // Called again on a finished profile it changes the first name alone: the
  // avatar, the admin flag and the date onboarding was completed stay.
  export const completeOnboarding = async (
    userId: UserId,
    firstName: PersonName,
    batch?: WriteBatch,
  ): Promise<UserProfile> => {
    // Memoized per request: the auth gate already read it.
    const profile = await repository.findProfile(userId)
    if (!profile)
      return repository.saveProfile({ userId, firstName, onboardingCompletedAt: new Date() }, batch)
    await repository.renameProfile(userId, firstName, batch)
    return { ...profile, firstName }
  }

  // Put an avatar on the profile, or take it off for the initials. The profile
  // must already exist: an avatar alone is not an account that finished
  // onboarding, and writing one would route the reader past the wizard.
  export const changeAvatar = async (
    userId: UserId,
    avatar: Avatar | undefined,
  ): Promise<UserProfile | 'no-profile'> => {
    const revised = await repository.reviseProfile(userId, ({ avatar: _previous, ...rest }) =>
      avatar ? { ...rest, avatar } : rest,
    )
    return revised ?? ('no-profile' as const)
  }

  // Erase the account's profile (account deletion).
  export const deleteProfile = async (userId: UserId) => {
    await repository.removeProfile(userId)
  }

  // Delete the account's auth identity — the last step of an account deletion,
  // after every trace of its data is gone.
  export const deleteAuthAccount = async (userId: UserId) => {
    await repository.removeAuthUser(userId)
  }
}
