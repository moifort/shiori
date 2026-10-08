# Award winners — design

## Problem

A reader who mostly reads science fiction has no way, inside Shiori, to see what the genre itself
considers its best books: the Hugo, Nebula or Locus winners, recent and past. They go to
Wikipedia, read a list in English, and have to work out for each title whether it exists in
French, on paper or as a recording, and whether they already hold it.

Découvrir already knows how to answer the second half for one book: an `EditionWatch` says
whether a book exists in a language and format, and an `AwaitedEdition` alerts the reader when it
comes out. What is missing is the list of winners and a section that crosses it with the
reader's library and those watches.

## Decision

A section in Découvrir, "Prix littéraires", showing the **winners** of the awards that belong to
the reader's most-read genre, in the app's language, in the tab's format (book or audiobook).

- **Winners only, never finalists.** A Hugo year has one winner and five or six finalists; the
  shortlists would multiply the section by six and bury the signal the section exists for.
- **The list of winners is versioned data, not a lookup.** Winners are historical facts that
  change once a year per award. A file in the repository, reviewed like code, costs nothing at
  runtime and cannot hallucinate. No model is ever asked who won.
- **What exists in the reader's language is the existing `EditionWatch`**, one per work, format
  and language, shared by every reader.
- **A winner not out in the app's language offers "Guetter"**, which creates an ordinary
  `AwaitedEdition`. It is offered on the row, never created on the reader's behalf (rule 5).

Out of scope: finalists, awards outside the table below, a winners' list for a genre picked by
hand from settings, friends' views.

## Rules

1. **The reader's genre.** Among the genres that have awards, the one with the most books in
   `read` or `reading`, a rating of four or five stars counting double. Books on the pile or
   dropped do not count: they describe intent, not taste. Ties go to the genre read most
   recently. A genre is offered only past a weight of three, so a single novel read by chance
   is not a taste; a reader with no such genre sees no section. A capsule above the list lets
   them switch to another genre past that weight; the choice is not stored.

2. **Awards per genre.** A fixed table in the domain. An award may serve two genres.

   | Genre | Awards |
   |---|---|
   | `science-fiction` | Hugo (novel), Nebula (novel), Locus SF, Arthur C. Clarke |
   | `fantasy` | World Fantasy (novel), Locus Fantasy, Hugo (novel), Nebula (novel) |
   | `horror` | Bram Stoker (novel) |
   | `crime`, `thriller` | Edgar (novel), CWA Gold Dagger, Grand Prix de Littérature Policière |
   | `literary-fiction` | Booker, Goncourt |

   The first version ships `science-fiction` and `fantasy` only. The other rows are added when
   their data is. The Grand Prix de l'Imaginaire is left out until its full list of French
   winners is checked: no source reachable when this was built gave every year.

3. **The winners file.** `server/domain/award/winners.ts`, one row per winner: the year of the
   ceremony, the English title it won under, its authors. Nebula rows are shifted by one year,
   since SFWA labels them by publication year. Checked against the Science Fiction Awards
   Database and Wikipedia; `scripts/check-award-winners.ts` compares it to Wikidata (award
   received, P166, with point in time, P585). Updated by one commit after each ceremony.

4. **Availability.** For each winner, the section reads the `EditionWatch` keyed on the work,
   the tab's format and the app's language. A winner whose watch was never looked up is looked
   up by the hourly pass, after the awaited editions, within its budget. Cadence differs from
   awaited editions, since nobody is waiting on these:
   - out in that language and format: never looked up again;
   - not found: every 60 days.

   The cost is one grounded call per winner and format, paid once for every reader. The SF and
   fantasy table holds roughly 300 winners, so about 600 calls the first time, then a few
   dozen a month.

5. **Guetter.** A winner not out in the app's language shows "Guetter" on its row. The app
   calls the existing `awaitScannedEdition` with the winner's title, authors and language:
   nothing of it is on any shelf, which is exactly that path's case, and its watch key is the
   very one the section reads, so no second lookup is paid. It counts against `MAX_AWAITED` (100)
   like any awaited edition. Nothing is awaited automatically: the two award lists alone hold
   more untranslated winners than a reader would want alerts for, and an automatic subscription
   would fill "À venir" with books the reader never chose.

6. **Already held.** A winner the reader holds in the tab's format, in any status, is not
   shown. Held means a book of theirs matches the watch's ISBN, or the
   watch's found title and an author, normalized as `shelfKey` does. Matching on the original
   title alone would miss every French copy.

7. **Order and size.** Newest year first. The strip shows the twelve most recent winners not
   held; "Tout voir" opens the full list, grouped by award, with a header per award saying how
   many of its winners the reader has read ("12 lauréats sur 70 lus").

8. **What a row shows.**
   - out: the found cover, title and date, the "+" that adds it as `to-read`, and in audiobook
     format the Audible link as the saga rows have it;
   - announced: the date, and "Guetter";
   - not found: the original title, "Non traduit" or "Pas encore en audio", and "Guetter".

## Data

- New domain `award`: `types.ts`, `winners.ts`, the genre table and the rules in
  `business-rules.ts`, `use-case.ts` for the section and the hourly pass.
- Watches live where `EditionWatch` lives already. One new shared collection,
  `award-interests`, one document per genre and language somebody looked at in the last three
  months: the hourly pass looks up only those winners, in both formats, after the awaited
  editions and the sagas, within the same run.
- No migration: a new collection and a new section.

## API

- `awardShelf(format: ReleaseFormat!, genre: Genre): AwardShelf` — null when the reader has no
  section. `genre` absent means the reader's own; the result names the genre it used, the
  genres the capsule may switch to, the twelve latest winners not held, and each award in full.
- No new mutation: `awaitScannedEdition` awaits a winner.

## Risks

- **Wikidata coverage of French awards** is thinner than of the Hugo and the Nebula. The seed
  script lists what it found, and the manual check is part of the commit.
- **French recordings are rare and Audible's catalogue misses some.** "Pas encore en audio" will
  be wrong for some books, as it is for sagas today.
- **Translated titles.** A watch that finds the wrong French book (a homonym) shows a wrong cover
  and hides a winner the reader does not hold. Same exposure as `EditionWatch` today.

## Tests

- Unit: the genre rule (weights, ties, threshold), the held rule (ISBN, title and author, the
  original title alone not matching), the cadence.
- Integration: the section for a fake library, with the read budget asserted; a winner awaited
  shows as awaited; the hourly pass looks up only the genres looked at, within its budget.
- Feature: `awardShelf` against the built schema.
