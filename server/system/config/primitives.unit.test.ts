import { describe, expect, test } from 'bun:test'
import { AscVendorNumber, GcpBillingTable } from '~/system/config/primitives'

describe('the App Store vendor number config value', () => {
  // Nitro coerces an all-digit env var to a number before config() reads it.
  // Rejecting that at boot is what crashed the function once the value was set.
  test('accepts the number Nitro coerces the env var to, and stringifies it', () => {
    expect(AscVendorNumber(94007373) as string).toBe('94007373')
  })

  test('still accepts a plain string', () => {
    expect(AscVendorNumber('94007373') as string).toBe('94007373')
  })

  test('rejects an empty value', () => {
    expect(() => AscVendorNumber('')).toThrow()
  })
})

describe('the GCP billing table config value', () => {
  test('accepts a fully qualified project.dataset.table', () => {
    const table = 'shiori-polyforms.billing_export.gcp_billing_export_v1_01B9B2_D51D23_1EF14D'
    expect(GcpBillingTable(table) as string).toBe(table)
  })

  test('rejects a value that is not three dot-separated parts', () => {
    expect(() => GcpBillingTable('billing_export')).toThrow()
  })
})
