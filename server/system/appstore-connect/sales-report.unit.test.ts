import { describe, expect, test } from 'bun:test'
import { parseSalesReport, premiumTotals } from '~/system/appstore-connect/sales-report'

// A trimmed daily SALES SUMMARY report the way Apple serves it: tab-separated,
// a header naming the columns, one row per product and country.
const HEADER = [
  'Provider',
  'Provider Country',
  'SKU',
  'Developer',
  'Title',
  'Version',
  'Product Type Identifier',
  'Units',
  'Developer Proceeds',
  'Begin Date',
  'End Date',
  'Customer Currency',
  'Country Code',
  'Currency of Proceeds',
  'Apple Identifier',
  'Customer Price',
].join('\t')

const row = (sku: string, units: number, proceeds: number, price: number, currency = 'EUR') =>
  [
    'APPLE',
    'US',
    sku,
    'Polyforms',
    'Shiori',
    '1.1',
    'IA9',
    String(units),
    String(proceeds),
    '07/22/2026',
    '07/22/2026',
    currency,
    currency === 'EUR' ? 'FR' : 'US',
    currency,
    '6749000000',
    String(price),
  ].join('\t')

describe('parsing a daily sales report', () => {
  test('reads the money columns off the header, wherever they sit', () => {
    const tsv = [HEADER, row('com.polyforms.shiori.app.premium.yearly', 2, 1.48, 2.08)].join('\n')

    const rows = parseSalesReport(tsv)

    expect(rows).toHaveLength(1)
    expect(rows[0]).toMatchObject({
      sku: 'com.polyforms.shiori.app.premium.yearly',
      units: 2,
      developerProceeds: 1.48,
      customerPrice: 2.08,
      proceedsCurrency: 'EUR',
      customerCurrency: 'EUR',
    })
  })

  test('an empty or headerless payload parses to nothing rather than throwing', () => {
    expect(parseSalesReport('')).toHaveLength(0)
    expect(parseSalesReport('not\ta\tsales\treport\nat\tall\t0\t0')).toHaveLength(0)
  })
})

describe('summing the month s premium revenue', () => {
  test('counts only the premium SKUs', () => {
    const tsv = [
      HEADER,
      row('com.polyforms.shiori.app.premium.monthly', 1, 2.12, 2.99),
      row('com.polyforms.shiori.app.somethingelse', 5, 10, 15),
    ].join('\n')

    const totals = premiumTotals(parseSalesReport(tsv))

    expect(totals.proceedsEur).toBeCloseTo(2.12, 10)
    expect(totals.grossEur).toBeCloseTo(2.99, 10)
  })

  test('multiplies by units and adds rows up', () => {
    const tsv = [
      HEADER,
      row('com.polyforms.shiori.app.premium.monthly', 2, 2.12, 2.99),
      row('com.polyforms.shiori.app.premium.yearly', 1, 1.48, 2.08),
    ].join('\n')

    const totals = premiumTotals(parseSalesReport(tsv))

    expect(totals.proceedsEur).toBeCloseTo(2 * 2.12 + 1.48, 10)
    expect(totals.grossEur).toBeCloseTo(2 * 2.99 + 2.08, 10)
  })

  test('converts foreign currencies with the fixed table', () => {
    const tsv = [HEADER, row('com.polyforms.shiori.app.premium.monthly', 1, 2.1, 2.99, 'USD')].join(
      '\n',
    )

    const totals = premiumTotals(parseSalesReport(tsv))

    expect(totals.proceedsEur).toBeCloseTo(2.1 * 0.91, 10)
    expect(totals.grossEur).toBeCloseTo(2.99 * 0.91, 10)
  })

  test('a refund subtracts through its negative units', () => {
    const tsv = [
      HEADER,
      row('com.polyforms.shiori.app.premium.monthly', 3, 2.12, 2.99),
      row('com.polyforms.shiori.app.premium.monthly', -1, 2.12, 2.99),
    ].join('\n')

    const totals = premiumTotals(parseSalesReport(tsv))

    expect(totals.proceedsEur).toBeCloseTo(2 * 2.12, 10)
  })
})
