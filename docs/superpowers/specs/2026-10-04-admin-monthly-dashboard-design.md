# Admin monthly dashboard — design

**Date:** 2026-10-04
**Status:** approved in conversation, pending spec review

## Goal

Turn the admin screen into a monthly dashboard the admin reads at a glance: what the month
costs and will cost, what it earns, who joined, and how the app is used day by day. The figures
must be the ones Google bills, not an estimate.

Access is unchanged: the shield button beside Settings in the home toolbar, shown only to a
profile with `admin: true`, opens the screen as a sheet.

## What the screen shows

From top to bottom:

1. **Month cost** — a full-width tile. The billed cost of the month so far, then
   `≈ 48 € fin de mois · +12 % vs sept.`. The comparison is red when the projection is above
   last month, green below. When last month has no billing data, only the projection shows.
2. **A 2×2 grid**
   - **Revenus Premium** — net proceeds of the month, gross as subtitle.
   - **Utilisateurs** — total accounts, `+N ce mois` as subtitle.
   - **Premium** — active subscribers, `+N ce mois` as subtitle.
   - **Gemini / Infra** — the month's cost split.
3. **Coûts par jour** — Swift Charts stacked bars, Gemini (purple) over infrastructure (gray),
   one bar per day, x axis covering the whole month so the days to come stay empty.
4. **Sessions par jour** — Swift Charts bars, one per day, whole-month axis. Reads
   "Indisponible" when GA4 is not configured.
5. **Détail** — kept from today's screen: scans, cache hits, Google searches by step
   (enrichment, catalogue, Découvrir), and when the projection last refreshed. The
   "CA du mois" and "Lecteurs" sections are removed; the tiles replace them.

## Data sources

| Figure | Source | Freshness |
|---|---|---|
| Gemini cost per day | Billing export, service `Gemini API` | Daily refresh, ~24 h billing lag |
| Infrastructure cost per day | Billing export, every other service | Daily refresh, ~24 h billing lag |
| Last month's total | Billing export, previous month | Daily refresh |
| Sessions per day | GA4 Data API, metric `sessions` by `date` | Daily refresh, ~24 h GA lag |
| Total accounts | `count()` on profiles (unchanged) | Daily refresh |
| New accounts this month | `count()` on profiles with `onboardingCompletedAt >= month start` | Daily refresh |
| Active Premium | Entitlements (unchanged) | Daily refresh |
| New Premium this month | Entitlements whose new `startedAt` falls in the month | Daily refresh |
| Premium revenue | App Store sales reports (unchanged) | Daily refresh |
| Scans, cache hits, searches by step | `ai-usage/{month}` counters (unchanged) | Live |

### Why the bill and not the tokens

The current screen prices the `ai-usage` token and search counters with constants. Checked
against the billing export on 2026-10-04, that estimate is structurally wrong for Shiori:

- On `shiori-polyforms`, Gemini 3 grounded searches are free up to 5,000 a month (SKU
  "Generate content search query gemini 3 free": 476 searches, €0.00 on October 3rd). The code
  bills every one at $14/1000. The "no allowance" finding in `ed8d545` came from the shared
  "Perso" project, whose allowance the other apps had already spent.
- Implicitly cached input tokens bill at a tenth of the rate; the code bills them in full.
- Searches the model ran while thinking are guessed (`billedSearches` falls back to 1).
- The USD→EUR rate is a constant.

The billing export is the same data AI Studio's Spend page shows (0.85 € in the export vs
0.87 € on the page for October, the gap being the export lag). Google offers no other
programmatic source of actual spend.

### The billing export

One standard export exists per billing account. Ours ("Paiement de Firebase",
`01B9B2-D51D23-1EF14D`) writes to
`vinarium-prod.billing_export.gcp_billing_export_v1_01B9B2_D51D23_1EF14D`, and holds the lines
of every project on the account. Shiori reads it there, filtered on its own project id. Moving
the export to a neutral project was considered and deferred by the user: Vinarium hosts it for
now.

What the export showed on 2026-10-04:

- Service description `Gemini API`, currency EUR, one row per SKU per usage day.
- Prepaid usage carries the label `goog-cloud-wallet: ais` and **no credit line**: `cost` is
  the consumption.
- Infrastructure services carry free-tier credits (Cloud Run Functions: 0.66 cost, -0.65
  credits in September). Credits are folded in, as today, so infra reads what is invoiced.
- Rows carry the model as label `goog-generativelanguage-model` but **no API key**: the
  standard export cannot split one key from another. See "Known limitation" below.
- Latest export at 04:12 UTC on October 4th covered October 3rd only.

## Server

### `GcpBilling` (`server/system/gcp-billing/index.ts`)

- **Bug fix:** the project filter becomes the function's own project
  (`NITRO_FIREBASE_PROJECT_ID`, already set by Terraform), no longer the project parsed out of
  the table name. Parsed from the table, it would read `vinarium-prod` and sum Vinarium's bill.
  The BigQuery job still runs in Shiori's project.
- `monthCost(month)` is replaced by `dailyCosts(month)`, returning one entry per usage day
  that has rows: `{ day, geminiEur, infraEur }`. One query:
  - grouped by `DATE(usage_start_time)` (UTC), restricted to the month's usage dates;
  - `geminiEur` = `SUM(cost + credits)` where `service.description = 'Gemini API'`;
  - `infraEur` = the same over every other service;
  - each value clamped at zero.
- Returns `undefined` when the table is not configured, as today.

### `GoogleAnalytics` (new, `server/system/google-analytics/index.ts`)

- `dailySessions(month)` calls `properties/{id}:runReport` with dimension `date`, metric
  `sessions`, date range month start → today, returning `{ day, sessions }[]`.
- Property id from new config `NITRO_GA4_PROPERTY_ID`; `undefined` when unset.
- The Data API requires the `analytics.readonly` scope, which the token firebase-admin hands
  out does not carry. The access token is requested from the metadata server with
  `?scopes=https://www.googleapis.com/auth/analytics.readonly`. Locally there is no metadata
  server, so the client answers `undefined` and the chart reads "Indisponible".

### Admin domain

- **Types**
  - `AdminMetricsProjection` loses `infra` and gains:
    - `costs?: { month, days: DailyCost[], previousMonthEur?: Eur }`
    - `sessions?: { month, days: DailySessions[] }`
    - `newUsers: Count`
    - `newPremium: Count`
  - `DailyCost = { day: Day, geminiEur: Eur, infraEur: Eur }`.
  - `DailySessions = { day: Day, sessions: Count }`.
  - `Day` is a new branded `"2026-10-04"` string in `shared`, with its Zod constructor and
    GraphQL scalar.
- **Business rules** (pure, unit tested)
  - `billedThrough(days)` — the last day with billing rows.
  - `monthTotals(days)` — Gemini, infra and total for the month.
  - `projectedMonthEur(total, daysCovered, daysInMonth)` — linear on the covered days.
  - `changeVsPreviousMonth(projected, previous)` — a ratio, undefined without a previous month
    or when it is zero.
  - `previousMonthOf(month)`, `daysInMonth(month)`, `monthStart(month)`.
  - `FIRST_BILLED_MONTH = '2026-10'` — Gemini was billed to the "Perso" project until
    October 3rd, so September holds Shiori's infrastructure but not its Gemini. A month before
    this one counts as absent: no comparison against it, rather than a misleading one.
  - `newPremiumIn(entitlements, month)` — entitlements whose `startedAt` falls in the month.
- **Removed:** `tokenCostEur`, `searchCostEur`, `aiCostEur`, the price constants and
  `USD_TO_EUR`. The recording path (`AdminCommand.record*Usage`, `ai-usage` documents) stays
  as is: scans, cache hits and searches by step still say *where* to act.
- **`AdminUseCase.refreshMetrics`** adds:
  - billing for the current month and the previous month's total;
  - GA4 sessions;
  - new accounts and new Premium.

  Each external source keeps the existing best-effort rule: missing config or a failure keeps
  the last stored figure for the same month and logs an error.
- **`AdminQuery.metrics`** joins the projection with the live `ai-usage` counters, as today,
  and derives the totals, projection and comparison from the stored days.

### Users and entitlements

- `UserQuery.joinedSince(date)` — `count()` aggregation on `onboardingCompletedAt >= date`.
- `Entitlement.startedAt?: Date` — new optional field, set from the signed transaction's
  `originalPurchaseDate`, which is stable across renewals and marks a free trial's start. No
  migration: an entitlement without it is not counted as new, and the next renewal
  notification fills it in.

### GraphQL

Additive only. On `AdminMetrics`:

- `costs: AdminMonthCosts` (nullable, null until billing has answered once), with:
  - `geminiEur`, `infraEur`, `totalEur`, `projectedEur`;
  - `previousMonthEur` (nullable);
  - `changeVsPreviousMonth` (nullable `Float`, e.g. `0.12`);
  - `billedThrough: Day`;
  - `days: [AdminDailyCost!]!`.
- `sessions: [AdminDailySessions!]` (nullable).
- `newUsers: Int!`, `newPremium: Int!`.

Deprecated in the same commit, never removed there (`docs/api-evolution.md`):

- `tokenCostEur` and `searchCostEur` — resolve to `0`, no source left.
- `aiCostEur`, `infraEur` and `totalCostEur` — resolve from `costs`.
- `premiumMonthly` and `premiumYearly` — the new screen no longer shows the split.

`bun run schema:check` must pass.

## iOS

- `AdminPage` is rebuilt as described above, staying pure and previewable. Its parts are split
  into the Features/Admin `components/` folders following the atomic layout the feature already
  uses. Icons sit top-aligned beside text, with no footer hints under sections.
- `AdminOperations.graphql` asks for the new fields and drops the deprecated ones;
  `apollo-ios-cli generate`. `Day` is mapped to `String` by hand, as `Eur` and `Count` are.
- `AdminModels` gains the costs, days and sessions, with fixtures:
  - `preview` — a mid-month with last month known;
  - `previewFirstMonth` — no comparison;
  - `previewBeforeRefresh` — billing and GA4 unavailable.
- Verified with a screenshot from the simulator through a temporary, never-committed launch
  harness, sent to the user before any install.

## Infrastructure

- **Terraform:**
  - enable `analyticsdata.googleapis.com`;
  - new variable `ga4_property_id` passed as `NITRO_GA4_PROPERTY_ID`;
  - `deploy.yml` passes `vars.GA4_PROPERTY_ID`.
- **Repository variables:**
  - `GCP_BILLING_TABLE` = the Vinarium-hosted table above;
  - `GA4_PROPERTY_ID` = the property's numeric id.
- **One-time grants, by the user** (Shiori's deploy account owns `shiori-polyforms` only and
  cannot grant on `vinarium-prod`):
  - BigQuery Data Viewer on dataset `vinarium-prod:billing_export` for Shiori's function service
    account;
  - Viewer on the GA4 property for the same service account (GA4 Admin → Property access
    management).
- Deploy through CI only.

## Known limitation

The billing export has no API-key dimension, and the local development key lives in
`shiori-polyforms`: on October 3rd, 0.75 € of the 0.85 € billed to Gemini was Gemini 3 Pro
Image generation from local prototype work, not the app. Until that key moves to a project of
its own, the Gemini figure includes local use. Filtering on the model label was rejected: it
silently breaks at the next model change.

## Error handling

- Billing or GA4 unavailable: the section reads "Indisponible"; the rest of the screen is
  unaffected.
- A refresh failure keeps the last stored figure and logs `error` (reported to Sentry), with a
  constant message and the details apart.
- A month with no billing rows yet (the 1st, before the first export): costs at zero, no
  projection.

## Testing

- `*.unit.test.ts`:
  - projection, comparison, month arithmetic, `billedThrough`;
  - new Premium in the month;
  - the `Day` primitive;
  - parsing of the BigQuery and GA4 responses.
- `*.int.test.ts` — `refreshMetrics` against the fake Firestore with the external clients
  mocked: each source failing on its own keeps the last figure; the read budget of
  `AdminQuery.metrics` stays at two document reads.
- `*.feat.test.ts`:
  - the new `AdminMetrics` fields;
  - `costs` and `sessions` null before the first refresh;
  - the deprecated fields still resolving.

## Out of scope

- Moving the billing export out of `vinarium-prod`.
- Moving the local Gemini key to its own project.
- History before the first billing data: the comparison appears once a previous month exists.
- Refreshing more often than daily: the billing data lags by a day anyway.
