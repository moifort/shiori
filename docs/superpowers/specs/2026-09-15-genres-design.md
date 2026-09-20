# Genres — design

> Written 2026.09.15. Replaces the free-form `genres` list with one genre from a fixed list
> plus free subgenres. Prerequisite of the home dashboard
> ([2026-09-15-home-dashboard-design.md](2026-09-15-home-dashboard-design.md)), whose genre
> breakdown needs a closed set to count against.

## 1. Why

`genres: Genre[]` holds up to four free labels chosen by the model. Two scans of two fantasy
novels come back as "Fantasy" and "Fantasy épique", so no statistic can be built on them.

## 2. The model

A book carries:

- `genre?: Genre` — **one** value from a fixed list. Optional: a book added by hand has no AI
  call to fill it, and the reader may leave it unset.
- `subgenres: Subgenre[]` — zero to three free labels, 1 to 100 characters each, written in
  the scan language like every other free-text field. "Dark fantasy", "space opera",
  "shōnen", "jeunesse" live here. The order is data: the enrichment prompt asks for the most
  representative first, because a library row has space for exactly one of them.

The format (book, manga, comic…) stays a separate field: genre classifies the content, not
the object. Audience ("young adult", "jeunesse") is not a genre either and goes to subgenres.

### Fixed list

Stored and sent to the model as the English slug. The app translates it.

| Slug | French label | Slug | French label |
|---|---|---|---|
| `fantasy` | Fantasy | `biography` | Biographie |
| `science-fiction` | Science-fiction | `history` | Histoire |
| `horror` | Horreur | `essay` | Essai |
| `crime` | Polar | `science` | Sciences |
| `thriller` | Thriller | `self-help` | Développement personnel |
| `romance` | Romance | `business` | Économie |
| `historical-fiction` | Roman historique | `art` | Art |
| `adventure` | Aventure | `cooking` | Cuisine |
| `literary-fiction` | Littérature | `travel` | Voyage |
| `humor` | Humour | `other` | Autre |
| `poetry` | Poésie | | |
| `drama` | Théâtre | | |

## 3. Server

- `book/types.ts`: `GENRES` const tuple and `Genre` union; `Subgenre` brand. `Book`,
  `NewBook`, `BookEdit` and `ScanResult` swap `genres` for `genre?` + `subgenres`.
- `book/primitives.ts`: `GenreValue` (Zod enum) and `Subgenre` (trimmed, 1–100).
- GraphQL: a `Genre` enum (`FANTASY`, `SCIENCE_FICTION`, …) replaces the `Genre` scalar; a
  `Subgenre` scalar reuses the brand constructor. `Book`, `ScanResult`, `NewBookInput` and
  `BookEditInput` expose `genre` (nullable) and `subgenres`. In `BookEditInput`, a null
  `genre` clears it and a null `subgenres` clears to an empty list.
- Scan: `ENRICHMENT_SCHEMA` constrains `genre` with `enum: [...GENRES]` (nullable) and asks
  for `subgenres`. The prompt names the list and says one genre only, the most specific, and
  `other` when none fits. A genre outside the list, or a fourth subgenre, is dropped by the
  existing `optional` parsing rather than failing the scan.
- The scan cache holds `ScanResult`s written with `genres`. A cached entry read back without
  `genre` / `subgenres` is read as no genre and no subgenres.

**No migration.** The production database is empty (decided 2026.09.15), so the field
changes shape in place.

## 4. iOS

- `Book.swift`: a `Genre` enum with French labels in `Localizable.xcstrings`, and
  `genre: Genre?` + `subgenres: [String]` on `Book`.
- Book screen: the genre shows as a row, the subgenres as the existing `TagList`.
- Library row: the genre and, beside it, the first subgenre as a single pill.
- Edit form: a `Picker` for the genre, built like the format picker, with a "Non renseigné"
  entry; a text field for subgenres, comma-separated, the way genres are typed today.
- Scan review: shows the genre and the subgenres, and passes them back to `addBook`.
- Manual add: unchanged.

## 5. Tests

- Unit: `GenreValue` and `Subgenre` constructors.
- Integration: a scan whose enrichment returns a genre outside the list keeps the book and
  drops the genre; more than three subgenres are cut to three.
- Feat: `addBook` / `updateBook` round-trip `genre` and `subgenres`; a null genre clears it.
