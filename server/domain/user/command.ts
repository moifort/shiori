import type { WriteBatch } from 'firebase-admin/firestore'
import type { PersonName, UserId } from '~/domain/shared/types'
import * as repository from '~/domain/user/infrastructure/repository'
import type { Avatar, UserProfile } from '~/domain/user/types'

export namespace UserCommand {
  // Persist the profile that marks onboarding done. The cellar dimensions are
  // written separately by UserUseCase.completeOnboarding, in the same batch.
  export const completeOnboarding = (userId: UserId, firstName: PersonName, batch?: WriteBatch) =>
    repository.saveProfile({ userId, firstName, onboardingCompletedAt: new Date() }, batch)

  // Put an avatar on the profile, or take it off for the initials. The profile
  // must already exist: an avatar alone is not an account that finished
  // onboarding, and writing one would route the reader past the wizard.
  export const changeAvatar = async (
    userId: UserId,
    avatar: Avatar | undefined,
  ): Promise<UserProfile | 'no-profile'> => {
    const profile = await repository.findProfile(userId)
    if (!profile) return 'no-profile' as const
    const { avatar: _previous, ...rest } = profile
    return repository.saveProfile(avatar ? { ...rest, avatar } : rest)
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
