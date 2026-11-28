import {
  appAccountToken,
  isActive,
  isGrantActive,
  planOf as planFrom,
  runningEntitlementOf,
} from '~/domain/entitlement/business-rules'
import * as repository from '~/domain/entitlement/infrastructure/repository'
import type { AppAccountToken, Entitlement, PremiumGrant } from '~/domain/entitlement/types'
import type { Plan, UserId } from '~/domain/shared/types'
import { config } from '~/system/config/index'

export namespace EntitlementQuery {
  // Every entitlement this account holds, one per store at most. Empty is the normal
  // state: most people never subscribe.
  export const allOf = async (userId: UserId): Promise<Entitlement[]> =>
    repository.findAllBy(userId)

  // The entitlement the account's screens describe: the active one that runs longest, else
  // the one that ended last. Absent when nothing was ever sold.
  export const of = async (userId: UserId): Promise<Entitlement | undefined> =>
    runningEntitlementOf(await allOf(userId), new Date())

  // Whose entitlement carries that account token. The way in for the App Store
  // notifications, which name an account only through the token they carry.
  export const byToken = async (token: AppAccountToken): Promise<Entitlement | undefined> =>
    repository.findByAppAccountToken(token)

  // The single answer to "what is this account entitled to". Every scan gate goes
  // through here.
  //
  // `NITRO_PREMIUM_USER_IDS` is a comp list — the accounts granted Premium
  // outright (the maker's own). It is an override, never the source: a real
  // entitlement is a verified store transaction. A TestFlight tester's grant is
  // the other way in, read only when the account holds no active entitlement, so
  // a subscriber's request costs no more than it did.
  export const planOf = async (userId: UserId): Promise<Plan> => {
    if (await holdsStorePremium(userId)) return 'premium'
    return isGrantActive(await repository.findGrantBy(userId)) ? 'premium' : 'free'
  }

  // Premium without any TestFlight grant: comped, or sold by a store.
  export const holdsStorePremium = async (userId: UserId): Promise<boolean> =>
    config().premiumUserIds.includes(userId) ||
    planFrom(await allOf(userId), new Date()) === 'premium'

  // What App Store Connect last said of this account as a TestFlight tester, if it was asked.
  export const grantOf = async (userId: UserId): Promise<PremiumGrant | undefined> =>
    repository.findGrantBy(userId)

  // Who is Premium right now: every active entitlement, every active grant, and the
  // comped accounts. The scheduled passes read it once to serve subscribers only, since
  // there is no free plan.
  export const subscribers = async (now = new Date()): Promise<Set<UserId>> => {
    const [entitlements, grants] = await Promise.all([
      repository.findAll(),
      repository.findAllGrants(),
    ])
    return new Set([
      ...config().premiumUserIds.map((id) => id as UserId),
      ...entitlements
        .filter((entitlement) => isActive(entitlement, now))
        .map((entitlement) => entitlement.userId),
      ...grants.filter((grant) => isGrantActive(grant)).map((grant) => grant.userId),
    ])
  }

  // The subscribers among these accounts, in the same order.
  export const subscribersAmong = async (userIds: readonly UserId[]): Promise<UserId[]> => {
    const premium = await subscribers()
    return userIds.filter((userId) => premium.has(userId))
  }

  // Every entitlement ever recorded, active or not, one per account and store — the admin
  // metrics refresh streams them to count who is Premium right now.
  export const all = async (): Promise<Entitlement[]> => repository.findAll()

  // The UUID the app must hand StoreKit when it starts a purchase, so the signed
  // transaction comes back naming its owner. Derived here and never on the
  // client: one implementation, no algorithm to keep in sync across two languages.
  export const tokenFor = (userId: UserId): AppAccountToken => appAccountToken(userId)
}
