#!/usr/bin/env bun
/**
 * Puts the product page's text up, in every language infra/fastlane/metadata/
 * holds, with the names of the subscriptions: what `appstore-setup.ts` does for
 * the text, without touching prices, availability or App Review. Run it after
 * editing a listing file or adding a language.
 *
 * Usage: bun scripts/appstore-listing.ts
 */
import { appId, editableVersion } from './appstore/connect'
import { nameSubscriptions, pushListing } from './appstore/listing'

const app = await appId()
const version = await editableVersion()
console.log(`Shiori ${version.attributes.versionString} (${version.attributes.appStoreState})`)
await pushListing(app, version.id)
await nameSubscriptions(app)
