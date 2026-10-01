# Kindle Connection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Kindle library connected like Audible — one Amazon sign-in, the books with covers
and sagas, read statuses that follow the reader each night — independent of Audible.

**Architecture:** A new library `kindle-api-ts` registers a Kindle-for-iPhone device, trades its
refresh token for `amazon.<domain>` cookies and reads "Manage your content and devices" (`mycd`).
`server/domain/kindle` mirrors `server/domain/audible`: a sealed connection per reader, an import
the reader ticks, a nightly pass behind its own admin route and Cloud Scheduler job. The iOS app
gains a Kindle source screen and an onboarding step offering Audible, Kindle or both.

**Tech Stack:** Bun, TypeScript, Nitro, Pothos GraphQL, Firestore (fake in tests), Terraform,
SwiftUI, Apollo iOS.

**Spec:** [docs/superpowers/specs/2026-09-30-kindle-connection-design.md](../specs/2026-09-30-kindle-connection-design.md)

## Global Constraints

- Runtime `bun` / `bunx`, never `npm` / `npx`. Biome: spaces, single quotes, no semicolons, width 100.
- English in code, comments and commits; French only in iOS on-screen copy.
- Never `console.*`: `createLogger('kindle')`, constant messages, context passed apart.
- Flat Firestore collections: `kindle-connections/{userId}`.
- Changelogs untouched. No push. Commit only this feature's paths (parallel sessions share the repo).
- Deprecate, never remove: `readKindleExport` and `importKindleBooks` keep working.
- Test suffixes run separately, as CI does: `bun test .unit.test`, `bun test .int.test`, `bun test .feat.test` (`mock.module` leaks across files in one run).
- `NITRO_KINDLE_KEY` seals the Kindle credentials; absent, Kindle mutations fail clearly.

---

### Task 1: `kindle-api-ts` — the library (gate)

**Files:** `../kindle-api-ts/` — `package.json`, `tsconfig*.json`, `biome.json`, `.gitignore`,
`README.md`, `CLAUDE.md`, `src/{index,types,locales,utils,client,cookies,library}.ts`,
`src/*.unit.test.ts`, `src/fixtures/content-ownership.json` (anonymised).

**Interfaces (produced):**
- `KINDLE_LOCALES: Record<KindleLocale, { domain, marketplaceId, countryCode }>` — the ten Amazon
  stores, retail marketplace ids.
- `login(locale) → { loginUrl, session: AuthSession, cookies: KindleCookie[] }`
- `register(code, session) → KindleCredentials { refreshToken, adpToken, devicePrivateKey, serial, locale }`
- `websiteCookies(credentials) → KindleCookie[]` — `POST /ap/exchangetoken/cookies`.
- `library(credentials) → KindleTitle[]` — `{ asin, title, authors: string[], coverUrl?,
  readStatus: 'READ' | 'UNKNOWN', originType: string, category: string, acquiredAt?: Date }`.
- `KindleApiError` with `kind: 'cookie-exchange' | 'csrf-missing' | 'unexpected-shape' | 'http'`.

- [ ] Write unit tests: login URL parameters and cookies; cookie header from an exchange answer;
  csrf token read off a page; `mycd` item mapping from the fixture (authors from
  `bookProducerDetails`, fallback split, `acquiredTime` to a Date); pagination by
  `numberOfItems`; `unexpected-shape` on a body without `items`.
- [ ] Implement with `fetch` injected through a module-level seam the tests replace.
- [ ] `bun test`, `bunx tsc --noEmit`, `bunx biome check`, `bun run build`; `git init` and commit.
- [ ] Wire into Shiori as `"kindle-api-ts": "file:../kindle-api-ts"` (to switch to the npm
  version once published — publishing is the maintainer's call).
- [ ] **Gate (needs the reader):** `scripts/kindle-probe.ts` connects through the dev server and
  reads `mycd` once. Documented in the final report; implementation continues meanwhile.

### Task 2: Kindle domain — types, primitives, vault, repository, commands

**Files:** `server/domain/kindle/{types,primitives,command,query}.ts`,
`server/domain/kindle/infrastructure/{kindle-api,credentials-vault,repository}.ts`,
`server/domain/kindle/command.int.test.ts`, `server/system/config/{index,primitives}.ts`,
`nitro.config.ts`, `.env.example`; book gains `kindleAsin` in `types.ts` / `command.ts`.

**Interfaces (produced):** `KindleAsin`, `KindleMarketplace`, `SealedKindleCredentials`,
`KindleConnection { userId, account?, pending? }`, `ConnectedKindleAccount { marketplace,
credentials, connectedAt, lastImportedAt?, autoSync?, readAsins?, lastSyncFailedAt? }`,
`KindleLogin`, `KindleCommand.{startLogin, completeLogin, recordPass, recordFailure, setAutoSync,
disconnect, deleteForUser}`, `KindleQuery.{accountOf, readersToSync}`,
`BookCommand.linkToKindle`.

- [ ] Int tests (fake Firestore, mocked `kindle-api`): start/complete login, expired and missing
  pending login, sealed credentials unreadable without the key, autoSync on a fresh connection,
  disconnect, record pass clears the failure.
- [ ] Implement mirroring `audible`; `config().kindleKey`.

### Task 3: Kindle rules and use-case — import and nightly sync

**Files:** `server/domain/kindle/business-rules.ts` (new rules), `export-rules.ts` (the CSV rules,
moved), `business-rules.unit.test.ts`, `export-rules.unit.test.ts`, `use-case.ts`,
`use-case.int.test.ts`.

**Interfaces (produced):** `isCataloguable(title)`, `sagaOf(title, author)`,
`importableFrom(title, ownedKeys)`, `bookFrom(importable)`, `kindleLinksFor(books, titles)`,
`readingChangesFor(books, titles, previouslyRead?)`, `acquiredSince(titles, cutoff?)`,
`readersDueForSync(connections)`; `KindleUseCase.{importableBooks, importBooks, syncLibrary,
syncEveryReader}` plus the CSV `read` / `importExport`.

- [ ] Unit tests: dictionaries and samples excluded; sagas from "X (Tome 3) - Y", "X #5 : Y",
  "X, tome 2", "Y (X Book 2)", "(French Edition)" stripped, unknown shapes keep no saga; read
  moves only on news, never back, first pass skips dropped; links by shelf key only for ebooks
  without an ASIN; acquired since a cutoff.
- [ ] Int tests: import re-reads Amazon and skips owned titles; sync catalogues new titles,
  moves news, records `readAsins`, leaves notes alone, one failing reader does not stop others;
  read budgets.

### Task 4: GraphQL, admin route, account deletion, infra

**Files:** `server/domain/kindle/infrastructure/graphql/{enums,errors,types,queries,mutations}.ts`,
`mutations.feat.test.ts`, `server/domain/shared/graphql/{builder,scalars,schema}.ts`,
`server/routes/admin/sync-kindle.post.ts`, `server/domain/user/use-case.ts`,
`infra/{secrets,scheduler}.tf`, `shared/schema.graphql`.

- [ ] Feat tests: connect, library, import, autoSync, sync now, disconnect, errors
  (`KINDLE_NOT_CONNECTED`, `KINDLE_UNAVAILABLE`, `KINDLE_NO_PENDING_LOGIN`,
  `KINDLE_LOGIN_EXPIRED`, `BAD_USER_INPUT`); the old CSV mutations still answer, deprecated.
- [ ] `bun run generate:graphql`, `bun run schema:check`.

### Task 5: iOS — Kindle source screen

**Files:** `ios/Shiori/Features/Import/GraphQL/Kindle.graphql` (and the CSV operations removed
from `Import.graphql`), `KindleAPI.swift`, `KindleModels.swift`, `KindleImportViewModel.swift`,
`KindleImportView.swift` (rewritten), `KindleBackgroundSync.swift`,
`components/pages/{KindleConnectPage,KindleSourcePage,KindleLibraryPage}.swift`;
`AudibleLogin` → `AmazonLogin`; `ImportSource.kindle` subtitle; generated Apollo code.

- [ ] Apollo codegen, `xcodebuild` for the simulator, `#Preview` fixtures for every page.

### Task 6: iOS — onboarding offers Audible, Kindle or both

**Files:** `Onboarding/OnboardingView.swift`, `Onboarding/components/pages/LibrariesOfferPage.swift`
(replaces `AudibleOfferPage.swift`), `Home/LibraryPreparation.swift`, `Home/HomeView.swift`.

- [ ] Preview fixtures, build, screenshot of the onboarding page and the Kindle source page.

### Task 7: Roadmap and verification

- [ ] `docs/roadmap.md` batch 6 rewritten; full verification: `bunx nitro prepare && bunx tsc
  --noEmit`, unit / int / feat suites separately, `bunx biome check`, `bun run schema:check`,
  iOS build.
