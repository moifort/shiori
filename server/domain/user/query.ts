import { Count } from '~/domain/shared/primitives'
import type { Count as CountType, UserId } from '~/domain/shared/types'
import * as repository from '~/domain/user/infrastructure/repository'
import type { MeView } from '~/domain/user/types'

export namespace UserQuery {
  // The signed-in user's identity and onboarding state. Returns nulls when no
  // profile exists yet — the app routes to onboarding on a missing timestamp.
  export const me = async (userId: UserId): Promise<MeView> => {
    const profile = await repository.findProfile(userId)
    return {
      userId,
      firstName: profile?.firstName,
      onboardingCompletedAt: profile?.onboardingCompletedAt,
      admin: profile?.admin === true,
    }
  }

  /** The first names behind a set of ids, for a list that names people. An
   *  account with no profile yet is simply absent from the map: the app then
   *  draws the friend without a name rather than an empty row. */
  export const namesOf = async (userIds: readonly UserId[]): Promise<Map<UserId, string>> =>
    new Map(
      (await repository.findProfiles(userIds)).map((profile) => [
        profile.userId,
        String(profile.firstName),
      ]),
    )

  // How many accounts completed onboarding — the admin metrics' user count.
  export const total = async (): Promise<CountType> => Count(await repository.countProfiles())
}
