import { describe, expect, test } from 'bun:test'
import {
  APP_STORE_URL,
  invitationCodeOfLink,
  invitationPage,
  invitationPlatformOf,
} from '~/utils/invitation-page'

const IPHONE =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1'
const ANDROID =
  'Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36'
const MAC =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15'

describe('the invitation page', () => {
  test('tells an iPhone, an Android phone and a computer apart', () => {
    expect(invitationPlatformOf(IPHONE)).toBe('iphone')
    expect(invitationPlatformOf(ANDROID)).toBe('android')
    expect(invitationPlatformOf(MAC)).toBe('desktop')
    expect(invitationPlatformOf('')).toBe('desktop')
  })

  test('sends an iPhone to the App Store, which opens the app when it is there', () => {
    const page = invitationPage('ABCD2345', 'iphone')
    expect(page).toContain(APP_STORE_URL)
    expect(page).not.toContain('shiori://')
  })

  test('on an iPhone, the badge copies the link to be pasted once the app is installed', () => {
    const page = invitationPage('ABCD2345', 'iphone')
    expect(page).toContain("clipboard.writeText(location.origin+'/invite/ABCD2345')")
    expect(page).toContain('collez')
    expect(invitationPage('ABCD2345', 'desktop')).not.toContain('clipboard')
  })

  test('never shows the code: the link carries it', () => {
    for (const platform of ['iphone', 'android', 'desktop'] as const) {
      const shown = invitationPage('ABCD2345', platform).replace(/<script>.*<\/script>/, '')
      expect(shown).not.toContain('ABCD2345')
    }
  })

  test('gives the link a preview: a title and the app icon', () => {
    const page = invitationPage('ABCD2345', 'iphone')
    expect(page).toContain('og:title')
    expect(page).toContain('og:image')
  })

  test('sends a computer to the App Store and asks for the link on an iPhone', () => {
    const page = invitationPage('ABCD2345', 'desktop')
    expect(page).toContain(APP_STORE_URL)
    expect(page).toContain('Ouvrez ce lien sur votre iPhone')
    expect(page).not.toContain('shiori://')
  })

  test('tells an Android phone the app is not there yet, without a store to nowhere', () => {
    const page = invitationPage('ABCD2345', 'android')
    expect(page).not.toContain(APP_STORE_URL)
    expect(page).toContain('Google Play')
  })

  test('reads only the shape of a code, upper-cased', () => {
    expect(invitationCodeOfLink('abcd2345')).toBe('ABCD2345')
    expect(invitationCodeOfLink('ABCD')).toBeUndefined()
    expect(invitationCodeOfLink('<script>')).toBeUndefined()
  })

  test('says a broken link is incomplete, and still offers the App Store', () => {
    const page = invitationPage(undefined, 'iphone')
    expect(page).toContain('incomplet')
    expect(page).toContain(APP_STORE_URL)
  })
})
