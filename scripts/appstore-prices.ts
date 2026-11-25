#!/usr/bin/env bun
/**
 * Changes the price of Shiori's subscriptions in App Store Connect to what
 * `appstore/prices.ts` says: the French price, and Apple's equivalent in every other
 * storefront. Idempotent: a subscription already at its French price is left alone.
 *
 * A price change reaches the store at once and applies to subscribers too
 * (`preserveCurrentPrice: false`): run it only on the owner's explicit yes on the figures.
 *
 * Usage: bun scripts/appstore-prices.ts          what would change, nothing written
 *        bun scripts/appstore-prices.ts --apply  write it
 */
import { api, appId, type Collection, post } from './appstore/connect'
import { PREMIUM_PRICES_EUR, type PremiumProductId } from './appstore/prices'

const apply = process.argv.includes('--apply')
/** The day the new price starts, `--from 2026-11-26`; tomorrow when absent: Apple refuses a change starting the same day. */
const from = process.argv.indexOf('--from')
const startDate =
  from > 0 ? process.argv[from + 1] : new Date(Date.now() + 86_400_000).toISOString().slice(0, 10)
const log = (line: string) => console.log(line)

/** Every page of a collection, which the API cuts at 200. */
const all = async <T>(path: string): Promise<Collection<T>> => {
  const data: Collection<T>['data'] = []
  const included: NonNullable<Collection<T>['included']> = []
  let next: string | undefined = `${path}${path.includes('?') ? '&' : '?'}limit=200`
  while (next) {
    const page: Collection<T> & { links?: { next?: string } } = await api(next)
    data.push(...page.data)
    included.push(...(page.included ?? []))
    next = page.links?.next?.replace('https://api.appstoreconnect.apple.com', '')
  }
  return { data, included }
}

type PricePoint = { customerPrice: string }

/** What France is or will be charged: the price with the latest start date, a change already
 *  scheduled included, so a second run the same day changes nothing. */
const frenchPriceOf = async (subscriptionId: string) => {
  const prices = await all<{ startDate: string | null }>(
    `/v1/subscriptions/${subscriptionId}/prices?filter[territory]=FRA&include=subscriptionPricePoint`,
  )
  const current = prices.data.sort((a, b) =>
    (b.attributes.startDate ?? '').localeCompare(a.attributes.startDate ?? ''),
  )[0]
  const pointId = current?.relationships?.subscriptionPricePoint?.data?.id
  const point = (prices.included as { id: string; attributes: PricePoint }[] | undefined)?.find(
    (included) => included.id === pointId,
  )
  return point?.attributes.customerPrice
}

const groups = await all<unknown>(`/v1/apps/${await appId()}/subscriptionGroups`)
const subscriptions = (
  await Promise.all(
    groups.data.map((group) =>
      all<{ productId: string; name: string }>(`/v1/subscriptionGroups/${group.id}/subscriptions`),
    ),
  )
).flatMap((page) => page.data)

for (const subscription of subscriptions) {
  const { productId, name } = subscription.attributes
  const wanted = PREMIUM_PRICES_EUR[productId as PremiumProductId]
  if (!wanted) {
    log(`${name}: no price decided for ${productId}, left alone`)
    continue
  }
  const current = await frenchPriceOf(subscription.id)
  if (current === wanted) {
    log(`${name}: already ${wanted} € in France, or scheduled to be`)
    continue
  }
  const french = (
    await all<PricePoint>(`/v1/subscriptions/${subscription.id}/pricePoints?filter[territory]=FRA`)
  ).data.find((point) => point.attributes.customerPrice === wanted)
  if (!french) throw new Error(`${name}: France sells no ${wanted} € price point`)
  const equivalents = await all<PricePoint>(
    `/v1/subscriptionPricePoints/${french.id}/equalizations?include=territory`,
  )
  const points = [
    { point: french.id, territory: 'FRA', price: wanted },
    ...equivalents.data.map((point) => ({
      point: point.id,
      territory: point.relationships?.territory?.data?.id ?? '',
      price: point.attributes.customerPrice,
    })),
  ].filter((entry) => entry.territory)
  const usa = points.find((entry) => entry.territory === 'USA')?.price
  log(
    `${name}: ${current ?? 'unpriced'} € → ${wanted} € in France, ${usa} $ in the USA, ${points.length} territories`,
  )
  if (!apply) continue
  for (const { point, territory } of points)
    await post('/v1/subscriptionPrices', {
      type: 'subscriptionPrices',
      // An approved subscription takes a dated change, never a second initial price.
      attributes: { preserveCurrentPrice: false, startDate },
      relationships: {
        subscription: { data: { type: 'subscriptions', id: subscription.id } },
        subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: point } },
        territory: { data: { type: 'territories', id: territory } },
      },
    })
  log(`${name}: priced in ${points.length} territories`)
}
if (!apply) log('Dry run: nothing written. Pass --apply to change the prices.')
