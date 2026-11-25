/**
 * What Shiori Premium costs, in euros as France sells it; every other storefront gets
 * Apple's equivalent of that price. The single source for `appstore-setup.ts`, which prices
 * a subscription that has none, and `appstore-prices.ts`, which changes a price already set.
 * Decided 2026-11-25 (docs/freemium-economics.md): 34.99 a year, 4.99 a month, up from
 * 17.99 and 1.99. Google Play's products carry the same figures, set in the Play Console.
 */
export const PREMIUM_PRICES_EUR = {
  'com.polyforms.shiori.app.premium.yearly': '34.99',
  'com.polyforms.shiori.app.premium.monthly': '4.99',
} as const

export type PremiumProductId = keyof typeof PREMIUM_PRICES_EUR
