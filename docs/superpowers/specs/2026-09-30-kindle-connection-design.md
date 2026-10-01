# Kindle connection — design

## Problem

The Kindle import that exists today reads the Amazon data export: the reader asks Amazon for their
data, waits days for an email, finds the right CSV in the archive and hands it over. What comes
back is a title and an author, nothing else — no cover, no saga, no reading status — and nothing
follows the reader afterwards.

Audible, by contrast, is a connection: one sign-in, the whole library with covers, and a nightly
sync. The reader wants the same for Kindle — a direct connection, complete records, and a status
that follows their reading.

## What Amazon actually answers

Probed on 2026-09-30 against a real amazon.fr account (79 titles in Cloud Reader, 165 owned):

- **Kindle Cloud Reader** (`lire.amazon.fr/kindle-library/search?libraryType=BOOKS`) answers
  clean paginated JSON — ASIN, title, authors as `"Surname, First:"`, cover, `resourceType`,
  `originType`. Its `percentageRead` is **0 on every title**, including books the reader finished
  or is reading: it does not follow Whispersync. Discarded as a source.
- **Manage your content and devices** (`www.amazon.fr/hz/mycd/digital-console/ajax`, activity
  `GetContentOwnershipData`, a `csrfToken` read off the page) answers every owned title with
  `readStatus` (`READ` / `UNKNOWN`), `acquiredDate`, `originType` (purchase, Prime, loan),
  `productImage`, authors and ASIN. **This is the source.**
- The reader's position (Whispersync) sits behind the web reader's own API (`startReading`), which
  refused a plain session call with a 403. Out of scope: status is read / not read, and "reading"
  stays a manual status in Shiori.
- Sagas are not a field. They live in the title ("Powerless (Tome 2) - Reckless": 40 titles out
  of 79) and are resolved by the existing series catalogue.

All of it is authenticated by Amazon session cookies only.

## Decision

A **Kindle connection, independent of Audible**: its own library, its own device registration, its
own credentials, its own nightly job. A reader with a Kindle and no Audible — or the reverse —
connects only what they use, and cutting one integration never touches the other.

The server does not keep session cookies. It keeps a device registration, like Audible, and
exchanges its refresh token for fresh `amazon.<domain>` cookies (`POST /ap/exchangetoken/cookies`)
on every pass. Nothing expires on the reader's side unless Amazon revokes the device.

The Amazon data export import is retired.

Out of scope: reading positions and "reading" status, highlights and notes, Kindle collections,
and reusing an Audible connection for Kindle.

## Gate: the exchange must work first

That cookies minted from a **Kindle device** registration open `mycd` is verified, not assumed.
It is the first task of the plan: the embryo of `kindle-api-ts` (`login`, `register`,
`websiteCookies`), a sign-in through the app, and one `mycd` call from the server. If Amazon
refuses those cookies, work stops and the design returns to a web-view session held server-side,
with the periodic reconnection that implies.

## `kindle-api-ts`

A new library in `../kindle-api-ts`, shaped like `../audible-api-ts` and published to npm the same
way (publishing is confirmed with the maintainer first):

- `login(locale)` — the PKCE sign-in URL for a Kindle-for-iPhone device, and the cookies to plant
  in the web view before loading it.
- `register(authorizationCode, session)` — registers the device; returns the refresh token, the
  device key, the serial and the locale. No access token is kept: nothing reads with one, so
  nothing rotates and nothing has to be written back after a pass.
- `websiteCookies(credentials)` — exchanges the refresh token for `amazon.<domain>` cookies.
- `library(credentials)` — reads `mycd`: fetches the `csrfToken`, pages `GetContentOwnershipData`
  by 50, and returns typed titles: ASIN, title, authors, cover URL, `readStatus`, `originType`,
  `resourceType`, acquisition date.

A change in `mycd`'s shape raises a typed error rather than returning an empty library. Unit tests
run against recorded, anonymised `mycd` answers.

## Server

`server/domain/kindle` is rewritten around the connection, mirroring `server/domain/audible`:

- `types.ts` / `primitives.ts` — `KindleAsin` (branded, one GraphQL scalar), `KindleConnection`
  (`userId`, `account?`, `pending?`), `ConnectedAccount` (`marketplace`, sealed `credentials`,
  `connectedAt`, `lastImportedAt?`, `autoSync?`), `PendingLogin`, `ImportableKindleBook`,
  `LibrarySync` counts, `SyncRun`.
- `infrastructure/kindle-api.ts` — the only module that reaches Amazon, and the only one tests
  mock.
- `infrastructure/credentials-vault.ts` — seals with `~/system/secret-box` under its **own key,
  `NITRO_KINDLE_KEY`**. Without it the Kindle mutations fail with a clear error and nothing else
  breaks.
- `infrastructure/repository.ts` — the flat collection `kindle-connections`, one document per
  reader.
- `command.ts` — `startLogin`, `completeLogin`, `recordImport`, `setAutoSync`, `disconnect`,
  `deleteForUser` (wired into account deletion).
- `business-rules.ts` — title to book, saga read off the title, status moves, links, which
  titles are offered. The CSV rules move to `export-rules.ts` and stay until the deprecated
  mutations are removed.
- `use-case.ts` — `importableBooks`, `importBooks`, `syncLibrary`, `syncEveryReader`.

The book gains an optional `kindleAsin`, beside `audibleAsin`. A new optional field: no migration.

`server/routes/admin/sync-kindle.post.ts` runs the nightly pass, admin-token gated and always
answering 200, like `sync-audible`. Its Cloud Scheduler job is declared in `infra/scheduler.tf`
and deployed by CI. Readers without a Kindle connection are never visited.

## Import

The import proposes, the reader disposes. `kindleLibrary` saves nothing: it lists the titles, with
those already on the shelf ticked off and untappable. `importKindleLibrary(asins)` re-reads Amazon
rather than trusting the client: the app sends identifiers, every stored field comes from the
source.

- **Offered:** titles bought, borrowed through Prime Reading or Kindle Unlimited. Never the free
  samples (`originType: Sample`, `udlCategory: KindleEBookSample`) nor the **dictionaries**
  Amazon files under every Kindle account (`originType: KindleDictionary` — 88 of the 165 titles
  of the account probed).
- **A book carries:** ebook format, title, authors (from `bookProducerDetails`, role `author`,
  already in reading order; the `authors` string split on commas otherwise), `kindleAsin`, the
  cover (`productImage`, served at full size), the acquisition date as its `addedAt`, and status
  `read` when `readStatus` is `READ`, `to-read` otherwise. A book imported as read is dated
  finished on its acquisition day: Amazon never says when, and import night would rewrite the
  reading statistics.
- **Sagas are read off the title**, which is where Amazon puts them: "Powerless (Tome 3) -
  Fearless" is volume 3 of Powerless, titled Fearless; "Boys of Tommen #5 : Taming 7" volume 5 of
  Boys of Tommen. A title no pattern recognizes keeps no saga rather than a guessed one. The saga
  is then named after its catalogue by `SeriesUseCase.namedAfterCatalogues`.
- **No model is called**: an import costs no scan.
- **Duplicates** are caught on the text — title plus first author, the existing shelf key — so a
  book already catalogued from Audible or a scan is not created twice.

## Nightly sync

For every reader connected with `autoSync` (absent reads as enabled):

1. **New titles** — those acquired since `lastImportedAt` are catalogued. A title the reader left
   unticked at import time predates that cutoff and is never forced on them.
2. **Status, one way only, on news only** — a title Amazon newly reports `READ` moves the book
   carrying that `kindleAsin` to read, dated tonight. Nothing ever moves it back: `UNKNOWN` does
   not mean unread, and a reader who marked a book read in Shiori must not see it undone. This is
   a deliberate difference with the Audible sync, which moves both ways.
   `READ` never goes away on Amazon, so the connection keeps the ASINs it last saw read
   (`readAsins`) and only a title absent from that set is news. Without it, a reader re-reading a
   book would see it put back on read every night. The first pass, which has no previous set,
   moves only books still on the pile or being read — never one the reader dropped.
3. **Books catalogued before the link** — ebooks without a `kindleAsin`, the CSV import's above
   all, are matched by shelf key and linked once, so they take part in the pass that links them.
4. Ratings, notes, hidden books and every other field are never touched.
5. A Kindle Unlimited loan returned disappears from Amazon; the book stays in Shiori.

One reader's failure is counted and logged, never costs the others their night.

## Errors

- A nightly pass that fails stamps `lastSyncFailedAt` on the account (cleared by the next pass that
  works), which the Kindle screen shows with an offer to connect again, and is logged with `warn`
  (reported to Sentry). A call the reader makes answers `KINDLE_UNAVAILABLE`.
- A `mycd` shape change is logged with `error`.
- Messages stay constant and the context is passed apart —
  `logger.warn('kindle cookie exchange failed', { error, userId })`.

## iOS

**Onboarding.** `AudibleOfferPage` becomes "Vos bibliothèques": two switches, Audible and Kindle,
both off, and one Amazon store picker for both. "Continuer" chains the sign-in of each source
switched on — Audible, then Kindle. As Audible already does at onboarding, each connection starts a
first pass in the background that catalogues the whole library, and the preparation screen waits
on both; there is no picker in the way of a reader who has not seen the app yet. "Plus tard"
connects nothing. A sign-in that fails or is cancelled moves on to the next one; it can be redone
from Settings.

**Settings.** Audible and Kindle stay two separate rows, each with its connection, its sync switch
and its disconnection. The Kindle row replaces `KindleImportView`.

**Picker.** The Kindle picker reuses the Audible picker's parts: cover, title, authors, a "Lu" badge
for `READ` titles, already-owned titles ticked off and untappable.

Screens are verified through `#Preview` fixtures and a screenshot sent for approval.

## Retiring the CSV import

`readKindleExport` and the CSV-taking `importKindleBooks` are **deprecated in the same commit**
that stops the app using them, never removed there (see [api-evolution](../../api-evolution.md)).
Their resolvers and the CSV reading rules keep working until the next release's
`bun run deprecations` pass removes them together. The new mutation therefore takes a
new name, `importKindleLibrary`. Batch 6 of [the roadmap](../../roadmap.md) is rewritten: it
currently says the opposite of this design.

## Tests

- `kindle-api-ts` — unit tests on recorded `mycd` answers.
- `*.unit.test.ts` — title to book, status mapping, samples excluded, names reversed.
- `*.int.test.ts` — import (re-read, duplicates skipped), sync (new titles after the cutoff,
  read one way, nothing else touched, a failing reader not stopping the others), disconnection,
  with read-budget assertions on `fake.docReads` / `fake.queryReads`.
- `*.feat.test.ts` — the Kindle queries and mutations against the built schema.
