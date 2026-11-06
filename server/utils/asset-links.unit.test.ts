import { describe, expect, test } from 'bun:test'
import { assetLinks } from '~/utils/asset-links'

describe('the App Links statement', () => {
  test('lists nothing until the app has a certificate', () => {
    expect(assetLinks('')).toEqual([])
    expect(assetLinks(' , ')).toEqual([])
  })

  test('trusts every certificate the app is signed with, upper-cased', () => {
    const [statement] = assetLinks('ab:cd, EF:01')

    expect(statement?.target).toEqual({
      namespace: 'android_app',
      package_name: 'com.polyforms.shiori.app',
      sha256_cert_fingerprints: ['AB:CD', 'EF:01'],
    })
    expect(statement?.relation).toEqual(['delegate_permission/common.handle_all_urls'])
  })
})
