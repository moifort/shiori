# Admin Monthly Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the admin screen as a monthly dashboard fed by the billed costs (billing export), GA4 sessions, and month-scoped user and Premium counts.

**Architecture:** The daily `refresh-metrics` job gains three sources: billing days from BigQuery, sessions from the GA4 Data API, and new-account and new-Premium counts. It stores them in the `admin-metrics/current` projection. `AdminQuery.metrics` derives totals, projection and comparison from the stored days. Token pricing is deleted; the `ai-usage` counters stay for scans, cache hits and searches by step. GraphQL is additive, with deprecations. iOS renders KPI tiles and two Swift Charts.

**Tech Stack:** Nitro + Bun, Pothos GraphQL, Firestore (fake in tests), BigQuery REST, GA4 Data API v1beta, SwiftUI + Swift Charts, Apollo iOS, Terraform.

**Spec:** `docs/superpowers/specs/2026-10-04-admin-monthly-dashboard-design.md`

## Global Constraints

- Code, comments and commits in English; on-screen iOS copy in French.
- `bun` / `bunx` only. Biome: single quotes, no semicolons, width 100.
- Never `console.*`; `createLogger(tag)`, constant message, details apart.
- GraphQL: additive only; fields the app stops asking for get `deprecationReason` in the same commit.
- Gemini service description in the export: `Gemini API`. First billed month: `2026-10`.
- Billing table: `vinarium-prod.billing_export.gcp_billing_export_v1_01B9B2_D51D23_1EF14D`; filter on Shiori's own project id; the job runs in Shiori's project.
- Run test suffixes separately (`bun test .unit.`, `.int.`, `.feat.`).
- Never touch `CHANGELOG*`, never push without "push", leave `ios/Shiori/ShioriApp.swift` (another session's edit) out of every commit.

## Review Focus

- First of the month before the first export: costs present with zero days → totals 0, no projection, no crash (unit test in Task 2).
- Projection from last month read on the 1st (stale `month`): must not show October's costs in November (int test in Task 5).
- Billing answers but the previous month predates `2026-10`: no comparison rather than an infra-only one (unit test in Task 2, int in Task 5).
- One source failing while the others answer: each keeps its own last same-month figure (int test in Task 5).
- A BigQuery day whose credits exceed cost: clamped to zero, never a negative `Eur` that would throw (unit test in Task 3).

---

### Task 1: `Day` primitive and scalar

**Files:** `server/domain/shared/types.ts`, `server/domain/shared/primitives.ts`, `server/domain/shared/primitives.unit.test.ts` (or the existing shared unit test file), `server/domain/shared/graphql/scalars.ts`, `server/domain/shared/graphql/builder.ts`

**Produces:** `type Day = Brand<string, 'Day'>`, `Day(value: unknown): Day` (regex `^\d{4}-\d{2}-\d{2}$`), GraphQL scalar `Day`.

- [ ] Test: `Day('2026-10-04')` passes; `Day('2026-10')` and `Day('04/10/2026')` throw.
- [ ] Implement as `Month` is; scalar `Day` described as `A calendar day, UTC. Example: "2026-10-04".`
- [ ] Run unit tests, commit `feat(shared): a calendar day primitive and scalar`.

### Task 2: Admin business rules on billed days

**Files:** `server/domain/admin/types.ts`, `server/domain/admin/business-rules.ts`, `server/domain/admin/business-rules.unit.test.ts`

**Produces:**
```ts
type DailyCost = { day: Day; geminiEur: Eur; infraEur: Eur }
type DailySessions = { day: Day; sessions: Count }
type MonthCosts = { month: Month; days: DailyCost[]; previousMonthEur?: Eur }
type MonthSessions = { month: Month; days: DailySessions[] }
type MonthCostsView = { geminiEur: Eur; infraEur: Eur; totalEur: Eur; projectedEur?: Eur;
  previousMonthEur?: Eur; changeVsPreviousMonth?: number; billedThrough?: Day; days: DailyCost[] }
FIRST_BILLED_MONTH: Month            // '2026-10'
isBilledMonth(month): boolean        // month >= FIRST_BILLED_MONTH
previousMonthOf(month): Month
daysInMonth(month): number
monthStart(month): Date              // UTC midnight on the 1st
monthCostsView(costs: MonthCosts): MonthCostsView
newPremiumIn(entitlements, month): Count   // startedAt within the month
```
Remove `tokenCostEur`, `searchCostEur`, `aiCostEur`, price constants and `USD_TO_EUR` with their tests. Keep `monthOf`, `freshUsage`, `freshStep`, `searchesOf`, `premiumBreakdown`.

- [ ] Tests:
  - `previousMonthOf('2026-01')` is `'2025-12'`.
  - `daysInMonth('2026-02')` is 28.
  - `isBilledMonth('2026-09')` is false and `'2026-10'` is true.
  - `monthCostsView` with days 1 to 3 summing 3 € in a 31-day month: projected 31, billedThrough the 3rd, change vs previous 31 € is 0.
  - Days stored out of order are sorted.
  - No days: totals 0, no projection, no billedThrough.
  - Previous month 0 or absent: no change.
  - `newPremiumIn` counts a `startedAt` in the month and ignores a missing or other-month `startedAt`.
- [ ] Implement; projection = `total / dayOfMonth(billedThrough) * daysInMonth`.
- [ ] Run, commit `feat(admin): month cost rules on billed days, no more token pricing`. This temporarily breaks `query.ts`, `use-case.ts` and the GraphQL types until Tasks 5 and 6; commit them together if typecheck is required per commit.

### Task 3: `GcpBilling.dailyCosts`

**Files:** `server/system/gcp-billing/index.ts`, `server/system/gcp-billing/daily-costs.ts`, `server/system/gcp-billing/daily-costs.unit.test.ts`, `server/system/config/index.ts`, `nitro.config.ts`

**Produces:** `GcpBilling.dailyCosts(month: Month): Promise<{ day: string; geminiEur: number; infraEur: number }[] | undefined>`; `parseDailyCosts(result)`; config `gcpProjectId` from runtimeConfig `firebaseProjectId` (env `NITRO_FIREBASE_PROJECT_ID`, already set by Terraform).

Query:
```sql
SELECT CAST(DATE(usage_start_time) AS STRING) AS day,
  SUM(IF(service.description = @gemini, cost + IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0), 0)),
  SUM(IF(service.description = @gemini, 0, cost + IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)))
FROM `<table>`
WHERE project.id = @project AND DATE(usage_start_time) BETWEEN @from AND @to
GROUP BY day ORDER BY day
```
Job posted to `projects/<gcpProjectId>/queries`; `undefined` when table or project id is unset.

- [ ] Test `parseDailyCosts`: rows parsed; negative clamped to 0; no `rows` gives `[]`; `jobComplete: false` throws.
- [ ] Implement, run, commit `fix(admin): read the bill per day for Shiori's project, wherever the export lives`.

### Task 4: `GoogleAnalytics.dailySessions`

**Files:** `server/system/google-analytics/index.ts`, `server/system/google-analytics/sessions-report.ts`, `server/system/google-analytics/sessions-report.unit.test.ts`, `server/system/config/{index,primitives,types}.ts`, `nitro.config.ts`

**Produces:** `GoogleAnalytics.dailySessions(from: string, to: string): Promise<{ day: string; sessions: number }[] | undefined>`; `parseSessionsReport(body)`; config `ga4PropertyId` (`Ga4PropertyId`, digits only).

Token from `http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token?scopes=https://www.googleapis.com/auth/analytics.readonly` with `Metadata-Flavor: Google`; returns `undefined` off Cloud Run (`process.env.K_SERVICE` unset).

- [ ] Test parse: `20261004` becomes `2026-10-04`, the sessions string becomes a number, no rows gives `[]`, sorted by day. Test `Ga4PropertyId('123456')` is OK and `'abc'` throws.
- [ ] Implement, run, commit `feat(admin): read daily sessions from GA4`.

### Task 5: Users, entitlements, refresh and view

**Files:**
- `server/test/fake-firestore.ts` (add `>=`)
- `server/domain/user/{query.ts,infrastructure/repository.ts}`
- `server/system/apple/{index.ts,types.ts}`
- `server/domain/entitlement/{types.ts,command.ts}`
- `server/domain/admin/{types.ts,use-case.ts,query.ts,admin.int.test.ts}`
- `server/routes/admin/refresh-metrics.post.ts` (doc comment)

**Produces:**
- `UserQuery.joinedSince(date: Date): Promise<Count>`.
- `Entitlement.startedAt?: Date` and `AppleTransaction.startedAt?: Date`, from `originalPurchaseDate`.
- `AdminMetricsProjection`: `{ totalUsers; newUsers; premium; newPremium; revenue?; costs?: MonthCosts; sessions?: MonthSessions; refreshedAt }`.
- `AdminMetricsView`: `{ costs?: MonthCostsView; sessions?: DailySessions[]; totalUsers; newUsers; premium; newPremium; revenue?; scans; cacheHits; searches; vision; enrichment; catalogue; discovery; refreshedAt? }`.

- [ ] Int tests (mock `~/system/gcp-billing` with `dailyCosts`, and `~/system/google-analytics`):
  - refresh stores the costs days plus the previous month total only when that month is billed;
  - it stores the sessions;
  - it counts `newUsers` from `onboardingCompletedAt` and `newPremium` from `startedAt`;
  - a failing billing or GA source keeps the last same-month figure and drops a stale-month one;
  - read budget: 1 doc read and 3 queries.
  - View: costs and sessions from another month are not served; newUsers and newPremium are 0 when `refreshedAt` is in an earlier month; it works before the first refresh.
- [ ] Implement; run `.int.`; commit `feat(admin): refresh the month's billed costs, sessions and newcomers`.

### Task 6: GraphQL

**Files:** `server/domain/admin/infrastructure/graphql/types.ts`, `.../queries.feat.test.ts`, `shared/schema.graphql` (generated)

**Produces:**
- `AdminMonthCosts { geminiEur infraEur totalEur projectedEur? previousMonthEur? changeVsPreviousMonth: Float? billedThrough: Day? days: [AdminDailyCost!]! }`
- `AdminDailyCost { day geminiEur infraEur }`
- `AdminDailySessions { day sessions: Int }`
- `AdminMetrics.costs?`, `sessions?`, `newUsers`, `newPremium`

Deprecated:
- `tokenCostEur` and `searchCostEur` → 0;
- `aiCostEur`, `infraEur` and `totalEur` → from `costs`;
- `premiumMonthly` and `premiumYearly`.

- [ ] Feat tests: forbidden for non-admin (kept); nulls before refresh; a seeded projection serves costs with its projection and the sessions; deprecated fields still resolve.
- [ ] `bun run generate:graphql`, then `bun run schema:check`; commit together with Task 9 operations (the deprecation lands where the app stops asking).

### Task 7: Infrastructure

**Files:** `infra/project.tf` (`analyticsdata.googleapis.com`), `infra/variables.tf` (`ga4_property_id`), `infra/function.tf` (`NITRO_GA4_PROPERTY_ID`), `.github/workflows/deploy.yml` (`ga4_property_id = "${{ vars.GA4_PROPERTY_ID }}"`).

- [ ] `terraform fmt -check` in `infra`; commit `chore(infra): enable the GA4 Data API and pass the property id`.

### Task 8: iOS models, API and operation

**Files:** `ios/Shiori/Features/Admin/{AdminModels.swift,AdminAPI.swift,GraphQL/AdminOperations.graphql}`, generated Apollo files.

- [ ] Operation asks for `costs { … days { day geminiEur infraEur } }`, `sessions { day sessions }`, `newUsers`, `newPremium`, `totalUsers`, `premiumTotal`, revenue, scans, cacheHits, searches, steps, refreshedAt. Deprecated fields are dropped.
- [ ] `cd ios && apollo-ios-cli generate`.
- [ ] Models: `AdminMetrics` with `month: Date`, `costs: Costs?`, `sessions: [DailySessions]?`, `newUsers`, `newPremium`. Fixtures `preview`, `previewFirstMonth`, `previewBeforeRefresh`. Days parsed as UTC midnight dates.

### Task 9: iOS page and charts

**Files:**
- `ios/Shiori/Features/Admin/components/pages/AdminPage.swift`
- new `components/molecules/AdminKpiTile.swift`
- new `components/organisms/AdminMonthCostCard.swift`
- new `components/organisms/AdminDailyCostChart.swift`
- new `components/organisms/AdminDailySessionsChart.swift`

- [ ] Cost card: total, `≈ X € fin de mois`, change red when up and green when down, hidden without a previous month.
- [ ] Grid: Revenus Premium (net, brut subtitle), Utilisateurs (+N ce mois), Premium (+N ce mois), Gemini / Infra.
- [ ] Stacked bars over the whole month (`chartXScale(domain:)`), Gemini purple, Infra gray, legend; sessions bars in blue; "Indisponible" when absent.
- [ ] Détail section kept (scans, cache, searches by step, refresh).
- [ ] Previews for the three fixtures. Build with `xcodebuild` (fresh derived data, `SWIFT_ENABLE_EXPLICIT_MODULES=NO`, `DEVELOPER_DIR`).
- [ ] Screenshot through a temporary harness built in a throwaway worktree at HEAD; send it to the user.
- [ ] Commit `feat(ios): the admin screen as a month dashboard with daily costs and sessions` (with the Task 6 schema and deprecations).

### Task 10: Grants and variables (with the user's access)

- [ ] BigQuery Data Viewer on `vinarium-prod:billing_export` for `shiori-runtime@shiori-polyforms.iam.gserviceaccount.com`.
- [ ] GA4 property: Viewer for the same account; note the property id.
- [ ] `gh variable set GCP_BILLING_TABLE` and `gh variable set GA4_PROPERTY_ID`.
- [ ] Full verification: typecheck, the three test suffixes, biome, schema:check.
