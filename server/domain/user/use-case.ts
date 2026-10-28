import { AnalyticsCommand } from '~/domain/analytics/command'
import { AudibleCommand } from '~/domain/audible/command'
import { AuthorCommand } from '~/domain/author/command'
import { AwaitedEditionCommand } from '~/domain/awaited-edition/command'
import { coverPrefixOf } from '~/domain/book/business-rules'
import { BookCommand } from '~/domain/book/command'
import { CatalogueCorrectionCommand } from '~/domain/catalogue-correction/command'
import { DiscoveryCommand } from '~/domain/discovery/command'
import { EntitlementCommand } from '~/domain/entitlement/command'
import { FriendshipCommand } from '~/domain/friendship/command'
import { KindleCommand } from '~/domain/kindle/command'
import { NarratorCommand } from '~/domain/narrator/command'
import { NotificationCommand } from '~/domain/notification/command'
import { QuotaCommand } from '~/domain/quota/command'
import { SeriesOpinionCommand } from '~/domain/series-opinion/command'
import type { PersonName, UserId } from '~/domain/shared/types'
import {
  avatarPathOf,
  avatarPrefixOf,
  isJpeg,
  MAX_AVATAR_BYTES,
} from '~/domain/user/business-rules'
import { UserCommand } from '~/domain/user/command'
import { UserQuery } from '~/domain/user/query'
import type { Avatar, AvatarColor, AvatarHero } from '~/domain/user/types'
import { objectStore } from '~/system/object-store'
import { ContentType } from '~/system/object-store/primitives'
import { atomically } from '~/utils/firestore'

export namespace UserUseCase {
  // Finish onboarding: persist the profile and the scans the account starts
  // with, in one batch, so a partial failure never leaves a user "half
  // onboarded" — either all of it lands or none of it does.
  //
  // The welcome scans are granted only the FIRST time, on an account with no
  // profile yet. The mutation stays reachable afterwards (a reader changing the
  // name they are addressed by), and re-granting there would turn a one-off gift
  // into a renewable one. The read is the one the auth gate already did,
  // memoized, so it costs nothing.
  export const completeOnboarding = async (userId: UserId, input: { firstName: PersonName }) => {
    const firstTime = (await UserQuery.me(userId)).onboardingCompletedAt === undefined
    return atomically(async (batch) => {
      if (firstTime) await QuotaCommand.grantWelcomeCredit(userId, batch)
      return UserCommand.completeOnboarding(userId, input.firstName, batch)
    })
  }

  // Change what stands for the reader: a hero, a photo of their own, their
  // initials on a colour, or nothing, which draws their initials on slate. A new photo lands in the bucket before
  // the profile points at it, and the one it replaces goes only once the
  // profile no longer does: a failure in between leaves an orphan file, never
  // a profile pointing at nothing.
  export const changeAvatar = async (
    userId: UserId,
    choice: { hero?: AvatarHero; color?: AvatarColor; photo?: Buffer },
  ) => {
    if ([choice.hero, choice.color, choice.photo].filter(Boolean).length > 1)
      return 'ambiguous' as const
    if (choice.photo && (choice.photo.length > MAX_AVATAR_BYTES || !isJpeg(choice.photo)))
      return 'invalid-photo' as const
    // Memoized per request: the command's own read of the profile is free.
    const me = await UserQuery.me(userId)
    if (me.onboardingCompletedAt === undefined) return 'no-profile' as const
    const before = me.avatar
    let avatar: Avatar | undefined
    if (choice.hero) avatar = { kind: 'hero', hero: choice.hero }
    else if (choice.color) avatar = { kind: 'initials', color: choice.color }
    else if (choice.photo) {
      const path = avatarPathOf(userId, new Date())
      await objectStore().write(path, choice.photo, ContentType('image/jpeg'))
      avatar = { kind: 'photo', path }
    }
    const saved = await UserCommand.changeAvatar(userId, avatar)
    if (saved === 'no-profile') return saved
    if (before?.kind === 'photo') await objectStore().remove(before.path)
    return saved
  }

  // Delete the account and every trace of it. Each step reaches a domain through
  // its public Command surface, never a repository — the domains own their
  // storage. The whole thing is idempotent, so a retry after a partial failure is
  // safe, and the order matters:
  //  1. Wipe every per-user collection in parallel, the analytics view
  //     included; they are independent. This
  //     forgets our entitlement record but does NOT cancel the App Store
  //     subscription — Apple owns that lifecycle, and the app says so. The
  //     Audible and Kindle connections go the same way: the sealed device
  //     credentials are dropped here, and the devices stay registered on the
  //     Amazon side until the reader removes them from their Amazon account.
  //  2. Delete the cover images and avatar photos, which live in the bucket rather than Firestore
  //     and would otherwise survive the account that paid to scan them.
  //  3. Drop the profile.
  //  4. Delete the Firebase Auth user LAST: if an earlier step fails the reader
  //     is still signed in and can retry, whereas deleting auth first would
  //     strand the data with nobody able to reach it.
  //
  // The series catalogue is deliberately untouched. It holds no reference to any
  // reader and serves everyone, so erasing one account's books must not erase a
  // saga that other readers are following. What this reader thought of those
  // sagas does go, though: an opinion names its reader and belongs to them.
  export const deleteAccount = async (userId: UserId) => {
    await Promise.all([
      BookCommand.deleteAllForUser(userId),
      AnalyticsCommand.deleteForUser(userId),
      EntitlementCommand.deleteForUser(userId),
      QuotaCommand.deleteAllForUser(userId),
      AudibleCommand.deleteForUser(userId),
      KindleCommand.deleteForUser(userId),
      SeriesOpinionCommand.deleteAllForUser(userId),
      AuthorCommand.deleteFavoritesOf(userId),
      NarratorCommand.deleteFavoritesOf(userId),
      CatalogueCorrectionCommand.deleteAllForUser(userId),
      FriendshipCommand.deleteAllForUser(userId),
      NotificationCommand.deleteForUser(userId),
      DiscoveryCommand.deleteForUser(userId),
      AwaitedEditionCommand.deleteAllForUser(userId),
    ])
    await Promise.all([
      objectStore().removeByPrefix(coverPrefixOf(userId)),
      objectStore().removeByPrefix(avatarPrefixOf(userId)),
    ])
    await UserCommand.deleteProfile(userId)
    await UserCommand.deleteAuthAccount(userId)
  }
}
