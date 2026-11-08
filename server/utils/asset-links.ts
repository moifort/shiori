/**
 * The App Links statement for the Android app, signed with the given SHA-256
 * fingerprints (comma-separated): none, and the list is empty.
 */
const PACKAGE_NAME = 'com.polyforms.shiori.app'

export const assetLinks = (fingerprints: string) => {
  const certificates = fingerprints
    .split(',')
    // Firebase writes them as bare hex; the statement wants colon-separated pairs.
    .map((fingerprint) => fingerprint.trim().toUpperCase().replaceAll(':', ''))
    .map((fingerprint) => fingerprint.match(/.{1,2}/g)?.join(':') ?? '')
    .filter((fingerprint) => fingerprint.length > 0)
  if (certificates.length === 0) return []
  return [
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: PACKAGE_NAME,
        sha256_cert_fingerprints: certificates,
      },
    },
  ]
}
