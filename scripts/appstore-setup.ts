#!/usr/bin/env bun
/**
 * Sets up Shiori's product page and subscriptions in App Store Connect, once,
 * from the Mac. Idempotent: what already holds the wanted value is left alone,
 * so a second run changes nothing and says so.
 *
 * What it sets, from the repository:
 * - the listing text of infra/fastlane/metadata/ in every language it holds (the
 *   same files `deliver` pushes with every release, through appstore/listing.ts,
 *   which `bun scripts/appstore-listing.ts` runs alone), the categories, the
 *   copyright;
 * - the age rating (nothing to declare: 4+), the third-party content answer, the
 *   availability in every territory;
 * - the App Review contact, copied from Vinarium's so no phone number sits in this
 *   public repository, and the review notes below;
 * - the two subscriptions: the monthly one created, both priced in France and
 *   equalized everywhere else, the yearly one opening on a free month, their names
 *   in every language, review notes and the paywall capture App Review asks for.
 *
 * App Privacy has no public API: it is answered in App Store Connect itself.
 *
 * Usage: bun scripts/appstore-setup.ts
 */
import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { basename, join } from 'node:path'
import {
  api,
  appId,
  type Collection,
  editableVersion,
  patch,
  post,
  type Single,
} from './appstore/connect'
import { nameSubscriptions, pushListing } from './appstore/listing'

const VINARIUM_APP_ID = '6789688303'
const metadata = join(import.meta.dir, '../infra/fastlane/metadata')
const paywall = join(import.meta.dir, '../screenshots/captures/fr/paywall.png')

const REVIEW_NOTES =
  "L'application nécessite Sign in with Apple. Les évaluateurs peuvent se connecter avec leur " +
  'propre identifiant Apple : un compte est créé automatiquement, aucun compte de démonstration ' +
  "n'est nécessaire. Le backend est en production. Fonctionnalité principale : photographier la " +
  'couverture d’un livre (appareil photo requis) pour créer sa fiche. Abonnement Shiori Premium ' +
  '(achat intégré) : le paywall s’ouvre depuis Réglages > Shiori Premium, et quand les scans ' +
  'gratuits du mois sont épuisés.'

const SUBSCRIPTION_REVIEW_NOTE =
  'Débloque les scans de couverture illimités, le scan d’une étagère entière et le catalogue ' +
  'complet des séries. Le paywall s’ouvre depuis Réglages > Shiori Premium.'

type Plan = {
  productId: string
  /** The reference name App Store Connect lists it under; what readers see is in appstore/listing.ts. */
  name: string
  period: 'ONE_MONTH' | 'ONE_YEAR'
  level: number
  /** In euros, as France sells it; every other storefront gets Apple's equivalent. */
  price: string
  freeTrial?: 'ONE_MONTH'
}

const PLANS: Plan[] = [
  {
    productId: 'com.polyforms.shiori.app.premium.yearly',
    name: 'Premium annuel',
    period: 'ONE_YEAR',
    level: 1,
    price: '17.99',
    freeTrial: 'ONE_MONTH',
  },
  {
    productId: 'com.polyforms.shiori.app.premium.monthly',
    name: 'Premium mensuel',
    period: 'ONE_MONTH',
    level: 2,
    price: '1.99',
  },
]

const text = async (path: string) => (await readFile(join(metadata, path), 'utf8')).trim()
const log = (line: string) => console.log(line)

/** Every page of a collection, which the API cuts at 200. */
const all = async <T>(path: string): Promise<Collection<T>['data']> => {
  const items: Collection<T>['data'] = []
  let next: string | undefined = `${path}${path.includes('?') ? '&' : '?'}limit=200`
  while (next) {
    const page: Collection<T> & { links?: { next?: string } } = await api(next)
    items.push(...page.data)
    next = page.links?.next?.replace('https://api.appstoreconnect.apple.com', '')
  }
  return items
}

const app = await appId()
const version = await editableVersion()
log(`Shiori ${version.attributes.versionString} (${version.attributes.appStoreState})`)

// MARK: - The listing

const [info] = (await api<Collection<{ appStoreState: string }>>(`/v1/apps/${app}/appInfos`)).data
if (!info) throw new Error('No app info')

await patch(`/v1/appInfos/${info.id}`, {
  type: 'appInfos',
  id: info.id,
  relationships: {
    primaryCategory: { data: { type: 'appCategories', id: await text('primary_category.txt') } },
    secondaryCategory: {
      data: { type: 'appCategories', id: await text('secondary_category.txt') },
    },
  },
})
log('categories set')

await pushListing(app, version.id, log)
await patch(`/v1/appStoreVersions/${version.id}`, {
  type: 'appStoreVersions',
  id: version.id,
  attributes: { copyright: await text('copyright.txt') },
})
log('copyright set')

// MARK: - Age rating, rights, availability

const rating = await api<Single<Record<string, unknown>>>(
  `/v1/appInfos/${info.id}/ageRatingDeclaration`,
)
// Nothing to declare: every descriptor at its "none", every yes/no at no. A
// fresh declaration holds nulls, so the fields are named rather than read back.
const NO = [
  'advertising',
  'ageAssurance',
  'gambling',
  'healthOrWellnessTopics',
  'lootBox',
  'messagingAndChat',
  'parentalControls',
  'socialMedia',
  'socialMediaAgeRestricted',
  'unrestrictedWebAccess',
  'userGeneratedContent',
]
const NONE = [
  'alcoholTobaccoOrDrugUseOrReferences',
  'contests',
  'gamblingSimulated',
  'gunsOrOtherWeapons',
  'horrorOrFearThemes',
  'matureOrSuggestiveThemes',
  'medicalOrTreatmentInformation',
  'profanityOrCrudeHumor',
  'sexualContentGraphicAndNudity',
  'sexualContentOrNudity',
  'violenceCartoonOrFantasy',
  'violenceRealistic',
  'violenceRealisticProlongedGraphicOrSadistic',
]
const declaration = Object.fromEntries([
  ...NO.map((key) => [key, false]),
  ...NONE.map((key) => [key, 'NONE']),
])
await patch(`/v1/ageRatingDeclarations/${rating.data.id}`, {
  type: 'ageRatingDeclarations',
  id: rating.data.id,
  attributes: declaration,
})
log('age rating declared: nothing to declare')

await patch(`/v1/apps/${app}`, {
  type: 'apps',
  id: app,
  attributes: { contentRightsDeclaration: 'DOES_NOT_USE_THIRD_PARTY_CONTENT' },
})
log('third-party content: none')

const territories = await all<{ currency: string }>('/v1/territories')
const availability = await api<Single<unknown>>(`/v1/apps/${app}/appAvailabilityV2`).catch(
  () => undefined,
)
if (availability) log('availability already set')
else {
  await api('/v2/appAvailabilities', {
    method: 'POST',
    body: JSON.stringify({
      data: {
        type: 'appAvailabilities',
        attributes: { availableInNewTerritories: true },
        relationships: {
          app: { data: { type: 'apps', id: app } },
          territoryAvailabilities: {
            data: territories.map((t) => ({ type: 'territoryAvailabilities', id: `\${${t.id}}` })),
          },
        },
      },
      included: territories.map((t) => ({
        type: 'territoryAvailabilities',
        id: `\${${t.id}}`,
        attributes: { available: true },
        relationships: { territory: { data: { type: 'territories', id: t.id } } },
      })),
    }),
  })
  log(`available in ${territories.length} territories`)
}

// MARK: - App Review

const vinariumVersion = (
  await api<Collection<unknown>>(`/v1/apps/${VINARIUM_APP_ID}/appStoreVersions?limit=1`)
).data[0]
const contact = vinariumVersion
  ? (
      await api<Single<Record<string, string | null>>>(
        `/v1/appStoreVersions/${vinariumVersion.id}/appStoreReviewDetail`,
      )
    ).data.attributes
  : undefined
const reviewAttributes = {
  contactFirstName: contact?.contactFirstName,
  contactLastName: contact?.contactLastName,
  contactPhone: contact?.contactPhone,
  contactEmail: contact?.contactEmail,
  demoAccountRequired: false,
  notes: REVIEW_NOTES,
}
const existingReview = await api<Single<unknown>>(
  `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`,
).catch(() => undefined)
if (existingReview?.data)
  await patch(`/v1/appStoreReviewDetails/${existingReview.data.id}`, {
    type: 'appStoreReviewDetails',
    id: existingReview.data.id,
    attributes: reviewAttributes,
  })
else
  await post('/v1/appStoreReviewDetails', {
    type: 'appStoreReviewDetails',
    attributes: reviewAttributes,
    relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
  })
log('App Review contact and notes set')

// MARK: - Subscriptions

const [group] = (
  await api<Collection<{ referenceName: string }>>(`/v1/apps/${app}/subscriptionGroups`)
).data
if (!group) throw new Error('No subscription group')

const existing = await all<{ productId: string }>(
  `/v1/subscriptionGroups/${group.id}/subscriptions`,
)

const subscriptionOf = async (plan: Plan) => {
  const found = existing.find((s) => s.attributes.productId === plan.productId)
  const attributes = {
    name: plan.name,
    groupLevel: plan.level,
    reviewNote: SUBSCRIPTION_REVIEW_NOTE,
  }
  if (found) {
    await patch(`/v1/subscriptions/${found.id}`, {
      type: 'subscriptions',
      id: found.id,
      attributes,
    })
    return found.id
  }
  const created = await post<Single<unknown>>('/v1/subscriptions', {
    type: 'subscriptions',
    attributes: {
      ...attributes,
      productId: plan.productId,
      subscriptionPeriod: plan.period,
      familySharable: false,
    },
    relationships: { group: { data: { type: 'subscriptionGroups', id: group.id } } },
  })
  log(`${plan.name}: created`)
  return created.data.id
}

const makeAvailable = async (subscriptionId: string) => {
  const current = await api<Single<unknown>>(
    `/v1/subscriptions/${subscriptionId}/subscriptionAvailability`,
  ).catch(() => undefined)
  if (current?.data) return
  await post('/v1/subscriptionAvailabilities', {
    type: 'subscriptionAvailabilities',
    attributes: { availableInNewTerritories: true },
    relationships: {
      subscription: { data: { type: 'subscriptions', id: subscriptionId } },
      availableTerritories: { data: territories.map((t) => ({ type: 'territories', id: t.id })) },
    },
  })
}

type PricePoint = { customerPrice: string }

const price = async (subscriptionId: string, plan: Plan) => {
  const priced = await all<unknown>(`/v1/subscriptions/${subscriptionId}/prices`)
  if (priced.length >= territories.length) return `${priced.length} territories already priced`
  const french = (
    await all<PricePoint>(`/v1/subscriptions/${subscriptionId}/pricePoints?filter[territory]=FRA`)
  ).find((point) => point.attributes.customerPrice === plan.price)
  if (!french) throw new Error(`${plan.name}: France sells no ${plan.price} € price point`)
  const equivalents = await all<PricePoint>(
    `/v1/subscriptionPricePoints/${french.id}/equalizations?include=territory`,
  )
  const points = [
    { point: french.id, territory: 'FRA' },
    ...equivalents.map((point) => ({
      point: point.id,
      territory: point.relationships?.territory?.data?.id ?? '',
    })),
  ].filter((entry) => entry.territory)
  for (const { point, territory } of points)
    await post('/v1/subscriptionPrices', {
      type: 'subscriptionPrices',
      attributes: { preserveCurrentPrice: false },
      relationships: {
        subscription: { data: { type: 'subscriptions', id: subscriptionId } },
        subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: point } },
        territory: { data: { type: 'territories', id: territory } },
      },
    })
  return `priced in ${points.length} territories`
}

const offerTrial = async (subscriptionId: string, plan: Plan) => {
  if (!plan.freeTrial) return
  const offers = await all<{ duration: string }>(
    `/v1/subscriptions/${subscriptionId}/introductoryOffers?include=territory`,
  )
  const offered = new Set(offers.map((offer) => offer.relationships?.territory?.data?.id))
  let added = 0
  for (const territory of territories) {
    if (offered.has(territory.id)) continue
    await post('/v1/subscriptionIntroductoryOffers', {
      type: 'subscriptionIntroductoryOffers',
      attributes: { duration: plan.freeTrial, offerMode: 'FREE_TRIAL', numberOfPeriods: 1 },
      relationships: {
        subscription: { data: { type: 'subscriptions', id: subscriptionId } },
        territory: { data: { type: 'territories', id: territory.id } },
      },
    })
    added += 1
  }
  log(`${plan.name}: free month offered in ${added} more territories`)
}

type UploadOperation = {
  method: string
  url: string
  offset: number
  length: number
  requestHeaders: { name: string; value: string }[]
}

/** The paywall, as App Review asks to see it for every subscription. */
const showPaywall = async (subscriptionId: string) => {
  const current = await api<Single<unknown>>(
    `/v1/subscriptions/${subscriptionId}/appStoreReviewScreenshot`,
  ).catch(() => undefined)
  if (current?.data)
    await api(`/v1/subscriptionAppStoreReviewScreenshots/${current.data.id}`, { method: 'DELETE' })
  const bytes = await readFile(paywall)
  const reserved = await post<Single<{ uploadOperations: UploadOperation[] }>>(
    '/v1/subscriptionAppStoreReviewScreenshots',
    {
      type: 'subscriptionAppStoreReviewScreenshots',
      attributes: { fileName: basename(paywall), fileSize: bytes.length },
      relationships: { subscription: { data: { type: 'subscriptions', id: subscriptionId } } },
    },
  )
  for (const operation of reserved.data.attributes.uploadOperations) {
    const response = await fetch(operation.url, {
      method: operation.method,
      headers: Object.fromEntries(operation.requestHeaders.map((h) => [h.name, h.value])),
      body: bytes.subarray(operation.offset, operation.offset + operation.length),
    })
    if (!response.ok) throw new Error(`paywall upload → ${response.status}`)
  }
  await patch(`/v1/subscriptionAppStoreReviewScreenshots/${reserved.data.id}`, {
    type: 'subscriptionAppStoreReviewScreenshots',
    id: reserved.data.id,
    attributes: {
      uploaded: true,
      sourceFileChecksum: createHash('md5').update(bytes).digest('hex'),
    },
  })
}

for (const plan of PLANS) {
  const id = await subscriptionOf(plan)
  await makeAvailable(id)
  log(`${plan.name}: ${await price(id, plan)}`)
  await offerTrial(id, plan)
  await showPaywall(id)
  const state = await api<Single<{ state: string }>>(`/v1/subscriptions/${id}`)
  log(`${plan.name}: ${state.data.attributes.state}`)
}

await nameSubscriptions(app, log)
