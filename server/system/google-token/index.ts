import { applicationDefault, getApp } from 'firebase-admin/app'

const METADATA_TOKEN_URL =
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token'

/** A token for the runtime's service account carrying `scope`, minted by the
 *  metadata server. The Play Developer and GA4 Data APIs only take a token
 *  carrying their own scope, and the one firebase-admin hands out carries
 *  cloud-platform alone; the metadata server mints one for any scope the
 *  account is asked for. Only on Cloud Run, which has a metadata server. */
export const scopedAccessToken = async (scope: string): Promise<string> => {
  const response = await fetch(`${METADATA_TOKEN_URL}?scopes=${scope}`, {
    headers: { 'Metadata-Flavor': 'Google' },
  })
  if (!response.ok) throw new Error(`Metadata server answered ${response.status}`)
  const { access_token } = (await response.json()) as { access_token: string }
  return access_token
}

/** A cloud-platform token for the function's own service account, through the
 *  credential firebase-admin already holds — no extra auth library for one
 *  bearer token. getApp() is safe here: the auth middleware initializes
 *  firebase-admin at boot, long before any caller runs (and
 *  applicationDefault() covers a bare use). */
export const cloudPlatformAccessToken = async (): Promise<string> => {
  const credential = getApp().options.credential ?? applicationDefault()
  const { access_token } = await credential.getAccessToken()
  return access_token
}
