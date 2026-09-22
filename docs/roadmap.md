# Roadmap

Shiori is built in batches. Each batch gets its own spec, its own plan, and ships before the
next one starts. Batches 1 and 2 are specified in
[specs/2026-09-14-shiori-design.md](superpowers/specs/2026-09-14-shiori-design.md); the rest
are recorded here so their constraints are not forgotten while the foundation is laid.

| Batch | Content | Status |
|---|---|---|
| 1 | Cover scan, enriched record, library, three reading statuses, five-star rating, note | **specified** |
| 2 | Series: shared catalogue, library grouping, series screen, related works | **specified** |
| 3 | Sharing a library with other people, `hidden` books excluded | **built** |
| 4 | Release alerts: forthcoming volumes, loved authors, French translations, Audible | **built** |
| 5 | Audible import | **built** |
| 6 | Kindle import | planned |
| 7 | The Découvrir tab: friends, awards, public ratings, AI suggestions | **built** |

## Batch 3 — Sharing

Decided during design, to be honoured when this is built:

- A shared library exposes **books, never series**. The series catalogue stays internal.
- Every book carries a `hidden` flag, built in batch 1. A hidden book is excluded from any
  shared view.

## Batch 4 — Release alerts

Entirely new ground: Vinarium has no push notifications at all. This batch needs APNs, device
token storage, a Cloud Scheduler job polling for publication dates, and a real answer to data
quality — publication dates are unreliable outside Google Books and Open Library.

It depends on batch 2: a forthcoming volume is already an identified row in the series
catalogue, which is what an alert attaches to.

Built and deployed with its APNs key. The data
quality problem has its answer: a date is kept as precisely as it was announced — a year, a
month or a day — and only a day ever fires an alert.

Four alerts, each switched on by the reader: a volume of a followed series, a new book from a
loved author, a new Audible release in a followed series, and, for a book read in English,
its French translation in print or on Audible. The forthcoming releases are also listed in
the Découvrir tab of batch 7, so the date lookup serves both. Broken down in
[tasks.md](tasks.md).

## Batch 5 — Audible import

Built. Audible, unlike Kindle, does have an API — the one its own iOS app talks to — and
[audible-api-ts](https://github.com/moifort/audible-api-ts) speaks it. The reader signs in to
Amazon once in a web view, the device is registered over PKCE, and the whole library comes back
with covers, sagas, listening progress and summaries. No model is called, so an import costs no
scan.

Three decisions worth keeping:

- **The credentials are sealed at rest.** A refresh token plus a device private key is a
  standing grant on somebody's Amazon account — the one secret Shiori holds that is dangerous
  away from Shiori. They are encrypted with a key kept in Secret Manager, so a Firestore export
  on its own is inert, and they go with the account on deletion.
- **The import proposes, the reader disposes.** `audibleLibrary` saves nothing, exactly as
  `scanBook` saves nothing. The app lists the titles, the reader ticks them, and
  `importAudibleBooks` re-reads the library from Amazon rather than trusting the client: the
  client sends identifiers, every stored field comes from the source. The nightly sync is the
  one exception, and it is one the reader switches on.
- **A duplicate is caught on the text, not on an identifier.** The match is title plus first
  author, folded the way series keys are folded, so a book scanned from the printed edition is
  recognized too — which the ASIN now kept on imported records would never have caught. The two
  coexist and answer different questions: the shelf key asks whether the reader already owns
  this story, loosely and across editions; the ASIN asks which record is this exact Audible
  title, and only it is precise enough for the sync to write a status into.

A fourth, added when the library learned to keep itself up to date:

- **The sync follows Audible, and only where it was invited.** A nightly Cloud Scheduler pass
  catalogues the titles bought since the previous one — dated by purchase, so a title the reader
  declined at import time is never forced on them — and moves the status of books carrying an
  ASIN in both directions. Ratings, notes and hidden books are never touched, and a book
  catalogued from the printed edition is never moved. `autoSync` on the connection is how a
  reader takes the whole thing back.

## Batch 6 — Kindle import

**This is an import, not a live sync.** Amazon publishes no Kindle library API, and the
Goodreads API has been closed since 2020. The realistic paths are the Amazon GDPR data export
("Request my data", a CSV) or manual entry. Scraping `read.amazon.com` would require the
user's Amazon credentials and is not an option. Note that the Audible connection of batch 5
does NOT help here: it authenticates against Audible's own API, which knows nothing about
Kindle.

## Batch 7 — AI reading suggestions

Grown into a tab of its own, Découvrir, meant to be what sets Shiori apart: it pushes the
reader to discover and to read more. A feed of shelves, each suggestion with its reason —
the friends' favourites, new Audible releases, what is coming out, award winners and the
books readers worldwide rate highest in the reader's genres, "because you loved X", and
genres the reader has never tried reached through one they love. Shipped in three waves,
the free signals first and the AI shelves last, since those depend on accumulated signal;
the waves are in [tasks.md](tasks.md). Computed weekly, with the shared parts (award lists,
public ratings) keyed like the series catalogue so they are paid for once. Batch 2 already delivers the zero-cost half of it: the recommendations
section on a book screen, listing the other volumes of its series.

## Deferred on purpose

### The reader's cover photo is not stored

A scanned book shows the publisher's cover when its ISBN finds one on Open
Library: `scanBook` checks it exists, and `addBook` keeps the URL as
`publishedCoverUrl`. A book without a known ISBN or cover shows the typographic
placeholder.

The photo taken for the scan is still sent for analysis and then dropped. It
would be the fallback for exactly those books, and the edition actually on the
shelf. Everything underneath exists — the object store, the private bucket, the
signed download URLs, and `coverPathOf` keyed by owner so an account deletion
sweeps them in one prefix delete — and `coverUrl` already prefers a stored photo
over the published cover. What is missing is the wiring: the scan must persist
the bytes it already holds and return a handle, and `addBook` must accept it.

Deferred by decision, not by oversight.

## Known blockers

Two things outside this repository stop the app from working end to end. Both need
a payment, so neither can be resolved from here.

### Resolved: Sign in with Apple

Registered on team `46C337T7YN`, the one that owns Vinarium:

- App ID `com.polyforms.shiori.app`, with Sign in with Apple and In-App Purchase
- Services ID `com.polyforms.shiori.signin`
- key `shiori-signin`, id `8SQ32NG589`, bound to the Shiori App ID as its primary

The key is bound to Shiori's own App ID rather than grouped under Vinarium's, so
it signs for this app alone. Identity Platform is live with it:
`apple.com`, `enabled = true`.

The earlier "membership expired" reading was a session on the wrong Apple ID —
`thibaut.mottet@gmail.com`, an Admin on App Store Connect carrying its own lapsed
personal membership, rather than `thibaut@polyforms.co`, the Account Holder. The
symptom is worth remembering: the Developer portal does not say "wrong account",
it silently redirects every Certificates, Identifiers & Profiles URL back to
`/account`.

Still to do on the Apple side: the App Store Connect app record, its API key for
the release workflow (issuer `58ccb3ea-10df-4d1e-ae5c-02fba75ab425`, alongside
`vinarium-ci`), and the subscription products.

### Resolved: the Gemini model and its credits

`gemini-2.5-flash`, which Vinarium runs on, is no longer served to new projects
at all: a fresh key gets a 404 on that model path pointing at 3.6. The model is a
named constant in `server/domain/scan/gemini.ts` for that reason — the next
retirement will land as a 404, not as a deprecation warning.

The pipeline has since been run end to end against the real API on a real cover.
It works, and two things came out of that run that no amount of reading the code
would have given:

- **A cold scan takes ~55 seconds.** Three grounded calls with thinking enabled.
  Vinarium's 60-second function ceiling left five seconds of margin, so the
  timeout is now 180. A request that tips over does not degrade gracefully: it
  504s after the models have already been paid for.
- **The title and the catalogue can disagree on language.** Scanning an English
  edition in French returns the printed title ("The Name of the Wind") while the
  catalogue lists the French canon ("Le Nom du vent"). This is deliberate rather
  than a bug — the book is the edition on the reader's shelf, the catalogue is
  the work — but the two sit side by side on the series screen, so it needs a
  decision before that screen ships. Matching is by volume number, not title, so
  nothing breaks either way.
