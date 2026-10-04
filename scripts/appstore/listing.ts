/**
 * The product page's text, in every language infra/fastlane/metadata/ holds a
 * folder for: the app's name, subtitle and privacy policy, the version's
 * description, keywords, promotional text and support URL, and the names the
 * subscriptions go by. A language the store lacks is created, the others are
 * updated; running it twice changes nothing.
 *
 * Screenshots are not here: scripts/upload-appstore-panels.ts puts them up.
 */
import { readdir, readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { api, type Collection, patch, post, type Single } from './connect'

const metadata = join(import.meta.dir, '../../infra/fastlane/metadata')

/** The App Store locales the listing is written in: a folder each, as `fr-FR`. */
export const listingLocales = async () =>
  (await readdir(metadata)).filter((entry) => /^[a-z]{2}-[A-Z]{2}$/.test(entry)).sort()

export const listingText = async (path: string) =>
  (await readFile(join(metadata, path), 'utf8')).trim()

/** What each subscription is called on the paywall and in the store, by locale. */
export const SUBSCRIPTION_TEXT: Record<
  string,
  Record<string, { name: string; description: string }>
> = {
  'com.polyforms.shiori.app.premium.yearly': {
    'fr-FR': {
      name: 'Premium annuel',
      description: 'Scans illimités et séries complètes, pour un an',
    },
    'en-US': {
      name: 'Premium Yearly',
      description: 'Unlimited scans and complete series, for a year',
    },
  },
  'com.polyforms.shiori.app.premium.monthly': {
    'fr-FR': {
      name: 'Premium mensuel',
      description: 'Scans illimités et séries complètes, pour un mois',
    },
    'en-US': {
      name: 'Premium Monthly',
      description: 'Unlimited scans and complete series, for a month',
    },
  },
}

type Localized = { locale: string }

/** Updates the localization of `locale` among `existing`, or creates it. */
const upsert = async (
  type: string,
  existing: Collection<Localized>,
  locale: string,
  attributes: Record<string, string>,
  parent: Record<string, { data: { type: string; id: string } }>,
) => {
  const current = existing.data.find((l) => l.attributes.locale === locale)
  if (current) {
    await patch(`/v1/${type}/${current.id}`, { type, id: current.id, attributes })
    return 'updated'
  }
  await post<Single<unknown>>(`/v1/${type}`, {
    type,
    attributes: { ...attributes, locale },
    relationships: parent,
  })
  return 'created'
}

/** The app's and the version's text, in every locale. */
export const pushListing = async (appId: string, versionId: string, log = console.log) => {
  const [info] = (await api<Collection<unknown>>(`/v1/apps/${appId}/appInfos`)).data
  if (!info) throw new Error('No app info')
  for (const locale of await listingLocales()) {
    const app = await upsert(
      'appInfoLocalizations',
      await api(`/v1/appInfos/${info.id}/appInfoLocalizations`),
      locale,
      {
        name: await listingText(`${locale}/name.txt`),
        subtitle: await listingText(`${locale}/subtitle.txt`),
        privacyPolicyUrl: await listingText(`${locale}/privacy_url.txt`),
      },
      { appInfo: { data: { type: 'appInfos', id: info.id } } },
    )
    const version = await upsert(
      'appStoreVersionLocalizations',
      await api(`/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations`),
      locale,
      {
        description: await listingText(`${locale}/description.txt`),
        keywords: await listingText(`${locale}/keywords.txt`),
        promotionalText: await listingText(`${locale}/promotional_text.txt`),
        supportUrl: await listingText(`${locale}/support_url.txt`),
      },
      { appStoreVersion: { data: { type: 'appStoreVersions', id: versionId } } },
    )
    log(`${locale}: name and subtitle ${app}, description and keywords ${version}`)
  }
}

/** The subscription group's name and each subscription's, in every locale. */
export const nameSubscriptions = async (appId: string, log = console.log) => {
  const [group] = (await api<Collection<unknown>>(`/v1/apps/${appId}/subscriptionGroups`)).data
  if (!group) throw new Error('No subscription group')
  const subscriptions = await api<Collection<{ productId: string }>>(
    `/v1/subscriptionGroups/${group.id}/subscriptions?limit=50`,
  )
  for (const locale of await listingLocales()) {
    await upsert(
      'subscriptionGroupLocalizations',
      await api(`/v1/subscriptionGroups/${group.id}/subscriptionGroupLocalizations`),
      locale,
      { name: 'Shiori Premium' },
      { subscriptionGroup: { data: { type: 'subscriptionGroups', id: group.id } } },
    )
    for (const subscription of subscriptions.data) {
      const text = SUBSCRIPTION_TEXT[subscription.attributes.productId]?.[locale]
      if (!text) throw new Error(`${subscription.attributes.productId} has no name in ${locale}`)
      await upsert(
        'subscriptionLocalizations',
        await api(`/v1/subscriptions/${subscription.id}/subscriptionLocalizations`),
        locale,
        text,
        { subscription: { data: { type: 'subscriptions', id: subscription.id } } },
      )
    }
    log(`${locale}: Shiori Premium and its ${subscriptions.data.length} plans named`)
  }
}
