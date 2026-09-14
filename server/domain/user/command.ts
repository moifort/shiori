import type { WriteBatch } from 'firebase-admin/firestore'
import type { PersonName, UserId } from '~/domain/shared/types'
import * as repository from '~/domain/user/infrastructure/repository'

export namespace UserCommand {
  // Persist the profile that marks onboarding done. The cellar dimensions are
  // written separately by UserUseCase.completeOnboarding, in the same batch.
  export const completeOnboarding = (userId: UserId, firstName: PersonName, batch?: WriteBatch) =>
    repository.saveProfile({ userId, firstName, onboardingCompletedAt: new Date() }, batch)

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
