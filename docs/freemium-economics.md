# Subscription economics

What a reader costs and what a subscriber pays, so the allowances in
`server/domain/quota/business-rules.ts` can be sized against real figures. Measured on
2026-11-25 from production, read-only: the billing export (`vinarium-prod.billing_export`), the
`ai-usage` and `admin-metrics` documents, and App Store Connect. Recalibrate the constants and
this page together whenever the bill moves.

Every figure below is either **measured** (read from a bill or a counter) or **estimated**
(derived, with its assumption stated).

## Where the app stands

| | Value | Source |
|---|---|---|
| Accounts | 7 (3 created in November) | `admin-metrics/current`, measured |
| Active Premium | 0 | `admin-metrics/current`, measured |
| Version on sale | 1.1, subscriptions approved | App Store Connect, measured |
| Products | yearly 34.99 € with a one-month free trial; monthly 4.99 €, no trial (17.99 € and 1.99 € until 2026-11-25) | `scripts/appstore/prices.ts` |
| Free plan | none since 2026-11-25: the trial is the way in, and an account without Premium waits behind the offer | owner's decision |

## What a scan costs

A scan is the app's only variable cost. It runs a vision call and grounded lookups: the book's
enrichment, plus its series and its author when they are new to the shared catalogue. A
grounded Gemini call bills about four Google searches; the first 5,000 a month are free, then
≈ 0.012 € each. Past the free searches, the grounded steps switch to Claude Haiku (since
2026-10-21), billed by Anthropic rather than on the GCP export.

| | Value | How |
|---|---|---|
| October 2026 Gemini bill | 53.12 € | billing export, measured |
| October scans | 787 | `ai-usage/2026-10`, measured |
| Scans' share of October searches | ~50% (enrichment 950 + catalogue 657 of 3,229; the rest is Découvrir's watch) | `ai-usage/2026-10`, measured |
| **Cost per scan, free searches not yet spent** | **≈ 0.03 €** (53.12 € × 50% ÷ 787) | estimated |
| **Cost per book added, every search paid** | **≈ 0.15 €** (2026-10-17, two shelf scans of ~21 books) | measured, `gemini-spend-investigation` |
| Claude Haiku past the free searches | ≈ 0.05 $ a call, 1 to 3 calls a new book | estimated, logged token counts; the Anthropic invoice was not read |

`SCAN_COST_EUR` carries the two ends: `withFreeSearches` 0.03, `allSearchesPaid` 0.15. The code
used to assume 0.01.

## What a subscriber pays

Prices since 2026-11-26 (`scripts/appstore/prices.ts`), decided by the owner on 2026-11-25; they
were 17.99 € a year and 1.99 € a month before, with no subscriber at the time of the change.
French prices, VAT 20%. Apple keeps 15% under the Small Business Program, 30% without it: the
enrolment form was sent on 2026-11-25 and awaits Apple's answer. Google Play keeps 15% on
subscriptions.

| Plan | Price | Before VAT | Net at 15% | Net at 30% |
|---|---|---|---|---|
| Yearly, one free month first | 34.99 € / year | 29.16 € | **24.78 € / year (2.07 € / month)** | 20.41 € / year |
| Monthly | 4.99 € / month | 4.16 € | **3.53 € / month** | 2.91 € / month |

Apple's equivalents elsewhere: 29.99 $ a year and 3.99 $ a month in the United States.

The quota code used to size the Premium ceiling on 1.48 € of monthly net for the yearly plan
at 17.99 €; the real figure was 1.06 €, and is 2.07 € at the current price.

## What the allowances cost per reader

Estimated at 0.03 € (low) and 0.15 € (high) a scan, if the allowance is used in full. There is
no free plan since 2026-11-25: an account without Premium scans nothing, its granted scans
waiting for a subscription (`exhausted`), and makes no paid model call at all — the GraphQL
route refuses grounded searches and Claude calls for it (`requireSubscriber`), and the
scheduled passes (nightly Kindle and Audible syncs, release watches, alerts, the month's
discoveries) serve subscribers only (`EntitlementQuery.subscribers`).

| Allowance | Scans | Cost if used |
|---|---|---|
| Welcome credit, once, at the end of onboarding (`WELCOME_SCANS`), spent during the trial | 50 | 1.50 to 7.50 € |
| Without Premium (`FREE_MONTHLY_SCANS`) | 0 (5 a month until 2026-11-25) | nothing |
| Premium welcome credit, once, first paid period (`PREMIUM_WELCOME_SCANS`) | 200 (500 until 2026-11-25) | 6 to 30 € |
| Premium monthly ceiling (`PREMIUM_MONTHLY_SCANS`) | 30 a month (100 until 2026-11-25) | 0.90 to 4.50 € a month |

A trial costs at most its 50 welcome scans and 30 monthly ones, 2.40 to 12 €, plus the page
lookups it opens; it earns nothing if cancelled, which the conversion rate has to pay for.

The Premium welcome credit was handed at the start of a free trial until 2026-11-25, and a
credit outlives the subscription: a trial started and cancelled could keep 500 scans worth 15
to 75 €, more than a year of the yearly plan netted. It is now handed at the first **paid**
period only (`earnsPremiumWelcome`). Credits already handed to trials were left alone: with no
subscriber yet there were none worth a migration.

**Decided by the owner on 2026-11-25:** the Premium ceiling went from 100 to 30 scans a month
and the Premium welcome from 500 to 200. At the old figures a month at the ceiling (3 to 15 €)
cost more than the yearly plan nets a month (2.07 €), and the welcome alone (15 to 75 €) could
exceed a first year's net (24.78 €). At the new ones a subscriber who uses everything costs at
most 6 to 30 € once, then 0.90 to 4.50 € a month: still above the net at the paid rate, which
is why the ceiling exists, and within it while the free searches last. The app's copy still
says "Scans illimités"; it is to be reworded with the Premium promise.

## Fixed costs and break-even

| | October 2026 | November 2026, to the 25th |
|---|---|---|
| Gemini API | 53.12 € | 0.19 € |
| App Engine, Scheduler, Secret Manager, Artifact Registry, Storage | ≈ 5.1 € | ≈ 1.5 € |
| Line labelled "Invoice" on the export | 11.65 € | — |
| Claude (Anthropic) | not on the export | not on the export |

Without the scans, a month costs roughly the infrastructure (≈ 2 to 5 €) plus Découvrir's
weekly watch, which ran about half of October's searches (≈ 26 €) once the free searches were
spent. Call it **≈ 30 € a month** at October's activity, an estimate.

Break-even on that fixed cost, before each subscriber's own scans: **≈ 15 yearly subscribers**
at 24.78 € net (30 € × 12 ÷ 24.78).

## Measuring it

- `admin-metrics` counts active Premium and, since 2026-11-25, those still in a free trial
  (`premiumTrial`), so paying subscribers are `premiumTotal − premiumTrial`.
- App Store proceeds reach the admin screen only once the repository variable
  `ASC_VENDOR_NUMBER` is set (App Store Connect → Payments and Financial Reports, the number
  at the top left); the Deploy workflow carries it into `NITRO_ASC_VENDOR_NUMBER`.
