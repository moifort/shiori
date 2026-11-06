import {
  APP_STORE_URL,
  MINIMUM_SUPPORTED_ANDROID_BUILD,
  MINIMUM_SUPPORTED_IOS_BUILD,
  PLAY_STORE_URL,
} from '~/system/app-support'

/**
 * Public client configuration, read by the iOS and Android apps at launch (before any
 * sign-in, so this route is whitelisted in the auth middleware). Drives the
 * force-update gate: builds below `minimumSupportedIOSBuild` are blocked.
 */
export default defineEventHandler((event) => {
  // A cached floor would defeat the foreground re-check on already-open apps.
  setResponseHeader(event, 'cache-control', 'no-store')
  return {
    minimumSupportedIOSBuild: MINIMUM_SUPPORTED_IOS_BUILD,
    appStoreUrl: APP_STORE_URL,
    minimumSupportedAndroidBuild: MINIMUM_SUPPORTED_ANDROID_BUILD,
    playStoreUrl: PLAY_STORE_URL,
  }
})
