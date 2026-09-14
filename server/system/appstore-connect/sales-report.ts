// Pure parsing of an App Store Connect sales report (TSV, one day, SUMMARY
// subtype) and the money math on its rows — kept free of IO so a fixture file
// can unit-test the whole thing.

/** One line of a sales report, reduced to what the revenue figure needs. */
export type SalesRow = {
  sku: string
  units: number
  developerProceeds: number
  customerPrice: number
  proceedsCurrency: string
  customerCurrency: string
}

// Only our subscription SKUs count as revenue: anything else in the report
// (a future one-off product, a bundle) would need its own line anyway.
const PREMIUM_SKU_PREFIX = 'com.polyforms.shiori.app.premium.'

// Fixed conversions into euros for the currencies Apple actually pays proceeds
// in. A steering figure, not accounting: revised by hand when a rate drifts.
// An unknown currency falls back to 1:1 rather than dropping the money.
const EUR_RATES: Record<string, number> = {
  EUR: 1,
  USD: 0.91,
  GBP: 1.17,
  CHF: 1.07,
  CAD: 0.66,
  AUD: 0.6,
  JPY: 0.0061,
  SEK: 0.085,
  NOK: 0.085,
  DKK: 0.134,
  PLN: 0.235,
  CZK: 0.04,
}

const inEur = (amount: number, currency: string): number => amount * (EUR_RATES[currency] ?? 1)

// The report is tab-separated with a header naming the columns; rows carry one
// product in one country each. Column positions are read off the header rather
// than assumed, since Apple appends columns over time.
export const parseSalesReport = (tsv: string): SalesRow[] => {
  const lines = tsv.split('\n').filter((line) => line.trim().length > 0)
  const header = lines[0]?.split('\t') ?? []
  const column = (name: string) => header.indexOf(name)
  const [sku, units, proceeds, price, proceedsCurrency, customerCurrency] = [
    column('SKU'),
    column('Units'),
    column('Developer Proceeds'),
    column('Customer Price'),
    column('Currency of Proceeds'),
    column('Customer Currency'),
  ]
  if (sku < 0 || units < 0 || proceeds < 0) return []
  return lines.slice(1).map((line) => {
    const cells = line.split('\t')
    return {
      sku: cells[sku] ?? '',
      units: Number(cells[units] ?? 0),
      developerProceeds: Number(cells[proceeds] ?? 0),
      customerPrice: Number(cells[price] ?? 0),
      proceedsCurrency: cells[proceedsCurrency] ?? 'EUR',
      customerCurrency: cells[customerCurrency] ?? 'EUR',
    }
  })
}

// What the Premium rows of one or more reports add up to, in euros: `proceeds`
// is what Apple pays out, `gross` what customers paid. Refunds come through as
// negative units and subtract on their own.
export const premiumTotals = (rows: SalesRow[]): { proceedsEur: number; grossEur: number } => {
  const premium = rows.filter((row) => row.sku.startsWith(PREMIUM_SKU_PREFIX))
  return {
    proceedsEur: premium.reduce(
      (sum, row) => sum + inEur(row.units * row.developerProceeds, row.proceedsCurrency),
      0,
    ),
    grossEur: premium.reduce(
      (sum, row) => sum + inEur(row.units * row.customerPrice, row.customerCurrency),
      0,
    ),
  }
}
