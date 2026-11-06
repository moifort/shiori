import { assetLinks } from '~/utils/asset-links'

/**
 * What tells Android that this host's invitation links belong to Shiori, as
 * `apple-app-site-association` tells iOS.
 *
 * Android verifies it when the app is installed, against the certificates the
 * app is signed with: the Play app signing key and the upload key. Without a
 * fingerprint the list is empty, and an invitation link opens the web page,
 * whose "Ouvrir dans Shiori" button still reaches the app through `shiori://`.
 */
export default defineEventHandler((event) => {
  setResponseHeader(event, 'content-type', 'application/json')
  setResponseHeader(event, 'cache-control', 'public, max-age=86400')
  return assetLinks(useRuntimeConfig(event).androidCertSha256)
})
