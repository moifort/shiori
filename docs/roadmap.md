# Roadmap

Shiori is built in batches. Each batch gets its own spec, its own plan, and ships before the
next one starts. Batches 1 and 2 are specified in
[specs/2026-09-14-shiori-design.md](superpowers/specs/2026-09-14-shiori-design.md); the rest
are recorded here so their constraints are not forgotten while the foundation is laid.

| Batch | Content | Status |
|---|---|---|
| 1 | Cover scan, enriched record, library, three reading statuses, five-star rating, note | **specified** |
| 2 | Series: shared catalogue, library grouping, series screen, related works | **specified** |
| 3 | Sharing a library with other people, `hidden` books excluded | planned |
| 4 | Release alerts for forthcoming volumes | planned |
| 5 | Kindle import | planned |
| 6 | AI reading suggestions | planned |

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

## Batch 5 — Kindle import

**This is an import, not a live sync.** Amazon publishes no Kindle library API, and the
Goodreads API has been closed since 2020. The realistic paths are the Amazon GDPR data export
("Request my data", a CSV) or manual entry. Scraping `read.amazon.com` would require the
user's Amazon credentials and is not an option.

## Batch 6 — AI reading suggestions

Suggestions drawn from followed series and highly rated books. Depends on accumulated signal,
so it comes last. Batch 2 already delivers the zero-cost half of it: the recommendations
section on a book screen, listing the other volumes of its series.

## Known blockers

Two things outside this repository stop the app from working end to end. Both need
a payment, so neither can be resolved from here.

### The Apple Developer Program membership is lapsed

On the team that owns Vinarium and the `com.polyforms.*` bundle prefix. While it
is expired the Developer portal refuses to mint an App ID, a Sign in with Apple
Services ID, or a `.p8` key, and App Store Connect redirects away from
Integrations — which is where an API key would come from.

Consequences, in order of how much they block:

- no Sign in with Apple, so the app cannot authenticate at all
- no App Store Connect app record, so no TestFlight and no release
- no in-app purchase products, so no paywall

Terraform is written to survive this: the Apple credentials default to blank and
the Identity Platform provider is skipped while they are. Filling
`apple_team_id`, `apple_services_id`, `apple_key_id` and `apple_private_key_path`
in `infra/terraform.tfvars` and re-applying attaches it, with no other change.

The browser session also has to be on the Apple ID that holds the membership.
`thibaut@polyforms.co` is the App Store Connect Account Holder;
`thibaut.mottet@gmail.com`, which the browser was signed into, is only an Admin
there and carries its own lapsed personal membership.

### The Gemini API has no prepaid credits

`gemini-3.6-flash` answers `RESOURCE_EXHAUSTED` on this project: the Gemini API
now requires prepayment, set up per project in AI Studio. Until that is done
every scan fails, though nothing else does — the library, the ratings, the notes
and the series screens all work without it, and a book can be added by hand.

Worth knowing: `gemini-2.5-flash`, which Vinarium runs on, is no longer served to
new projects at all. A fresh key gets a 404 on that model path pointing at 3.6.
The model is a named constant in `server/domain/scan/gemini.ts` for that reason —
the next retirement will land as a 404, not as a warning.
