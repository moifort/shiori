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
