# Recommended books — design

## Problem

A bookseller, a colleague or a friend says "read this". Today the reader has two bad options:
put it on the pile, which claims a book they do not own and inflates every statistic that counts
the pile, or forget it. The friend who recommended it can be recorded (`Book.recommendation`),
but only from the book's menu after it exists, never while scanning.

## Decision

A fifth reading status, `recommended`: a book the reader was told about and does not hold. It is
catalogued like any other book — scan, cover, genre, series — and lives on its own shelf, kept
out of everything that describes the reader's library. Adding it to the library is a status
change to `to-read`.

A status rather than a flag or a collection: "recommended" excludes "on the pile", "reading" and
"read" exactly as those exclude each other. A `owned: false` boolean beside the status would allow
"reading a book I do not have", and a separate collection would duplicate the scan, the cover and
every form, then copy the document over at purchase.

No migration: a new enum value and a new optional input field.

Out of scope: a buy link with an affiliate tag, a reminder to buy, recommended books in the
friends' views.

## Rules

1. **Lifecycle.** `recommended` carries no reading date. It leaves by:
   - the "+" on its page → `to-read`;
   - any status picked in the status picker;
   - a rating or a heart → `read`, as `statusAfterRating` already does for `to-read`. A heart
     is always given with five stars, so it follows the same path;
   - an Audible or Kindle import of the same book (rule 5).
2. **Excluded from the library's description.** A recommended book is never in:
   - the library's `all` and `favorites` views;
   - the Sagas and Authors shelves;
   - any statistic: pile, counts, genres, series progress, months to clear the pile;
   - Découvrir: it makes no saga and no author followed (`isDiscoverable`, `watchedAuthorsOf`);
   - anything a friend sees: their view of the library, the profile, the activity, the
     `bookCount`.
3. **Duplicates.**
   - A recommended book still holds its shelf key: adding a friend's copy of it is refused as
     "already in the library", and the friend's "+" is greyed out.
   - On a shelf photo it is flagged `recommended` rather than `owned`: the reader sees they
     spotted it, not that they hold it.
4. **Recommender.** `recommendation` (name + comment) stays available on every book, whatever
   its status. It becomes writable at creation, so a scan's review saves the book and its
   recommender in one call.
5. **Audible and Kindle guard.** When an import meets a book whose shelf key matches a
   recommended record, it does not skip it as a duplicate:
   - it moves the record to `to-read`, or to the status the store reports;
   - it attaches the ASIN (Audible);
   - it sets the store's format;
   - it keeps the recommendation.

   Without this, a recommended book bought on Audible would never be imported.
6. **Buy links.** A recommended book always shows two stores:
   - **Amazon.** `/dp/{isbn10}` when the ISBN converts, otherwise a search on the ISBN-13,
     otherwise a search on title and author. Same marketplace rule as `storeUrlOf`.
   - **Audible**, depending on the edition's language:
     - **In the app's language.** `DiscoveryUseCase.audioEditionOf` asks Audible's catalogue.
       Found → the recording's page. Not found → no Audible link. The page offers "Guetter la
       version audio" instead, through the existing awaited-edition offer with
       `unrecorded: true`, as a friend's book already does.
     - **In another language.** A search on title and author, plus the existing "Guetter la
       traduction / la version audio" offer.

   The awaited edition is an explicit request on one book, so it does not contradict rule 2.

## Server

- `READING_STATUSES` gains `recommended`, placed first in lifecycle order, and GraphQL
  `ReadingStatus` gains `RECOMMENDED`.
  - `statusTiers` puts it last. It never shares a view with the other statuses, but the order
    must be total.
  - `datesAfter` clears both dates, as `to-read` does.
  - `hasConsistentDates` refuses any date on it.
- Library query: a third mode, `recommended`.
  - It lists the recommended books with **the same sections and the same order as the `all`
    view**: sagas grouped, then the standalone shelf, ordered on `statusChangedAt`.
  - `all` and `favorites` drop `recommended` from the statuses they read, as the friends' view
    already drops `dropped`.
- `addBook` input gains an optional `recommendation: RecommendationInput`, stored through
  `storedRecommendation`.
- New query `recommenderNames: [PersonName!]!`: the names already written in `recommendation`,
  most used first, drawn from one read of the library (like `ShelfVocabulary`, which it may
  join).
- `Book` gains two nullable fields, resolved only on a recommended book:
  - `amazonUrl: String`, as `storeUrl` is on an awaited edition;
  - `audibleUrl`: it already exists, and is extended to the found recording or the search.
  The awaited-edition offer for a recommended book passes `unrecorded` from `audioEditionOf`
  instead of `false`.
- Analytics (`dashboardOf`, `sharedShelfOf`), discovery, series progress, author pages and
  friendship filter `recommended` out wherever they filter `dropped` or read "all books".
- Dashboard gains `recommended: [BookView!]!`, the latest recommended books (limit 10, newest
  first), read in the same library pass.
- Scan (shelf photo): `DetectedBook` gains `recommended: Boolean!`. `owned` becomes false for a
  book held only as recommended.
- Friendship:
  - `CopiedStatus` and its GraphQL enum gain `RECOMMENDED`. It is an addition, so no
    deprecation.
  - The recommender stays the friend's first name, as it is today for every copy.
- Audible and Kindle import and sync: rule 5, in the matching step before the duplicate skip.

## iOS

- **Status picker** (`ReadingStatusPicker`): four segments, **Conseillé · À lire · En cours ·
  Lu**. "Abandonné" stays in the book's menu.
- **"Conseillé par" field**, shared by the scan review, manual add and the edit form:
  - it sits under the status, visible whatever the status, open by default on Conseillé;
  - it holds a name field with suggestions from `recommenderNames` as the reader types (the
    subgenre autocomplete's behaviour), the Contacts button, and the comment;
  - the fields are extracted from `RecommendationSheet`, which keeps using them.
- **Library › Livres.** `LibraryMode` gains `recommended`, the **rightmost** button after
  Favoris, icon `hand.thumbsup.fill`.
  - Same sections and order as Tout.
  - The status filter menu is hidden in this mode.
  - Rows show "par {name}" in place of the status tag.
  - It has its own cache key, like the other modes.
- **A recommended book's page:**
  - the Amazon and Audible pills in the header, or the "Guetter" offer;
  - a **+** in the toolbar that moves it to À lire;
  - stars kept (rating it makes it read);
  - reading dates hidden.
- **Dashboard.** A "Livres conseillés" cover row after "Nouveaux favoris de vos amis". It is
  hidden when empty, and tapping its heading opens the Conseillés view.
- **A friend's library.**
  - The row "+" (`TakeButton`) adds straight to Conseillé, in the friend's format, with no
    format menu.
  - The "+" menu on a friend's book offers, in order: Conseillé, then "Ajouter à ma pile" and
    "Je l'ai déjà lu" per format, then the awaited editions.
- **Shelf import checklist.** A recommended book comes ticked, badged "Conseillé".
  - Keeping it moves the record to À lire rather than adding a second one: a shelf the reader
    photographs is theirs.

## Testing

- **Unit:**
  - `statusAfterRating` from `recommended`;
  - dates refused on `recommended`;
  - the library mode filters;
  - the Amazon URL fallbacks;
  - Audible matching a recommended record (rule 5);
  - analytics ignore recommended books.
- **Int:**
  - add with a recommendation;
  - `recommenderNames` in one query read;
  - the friend copy as `recommended`;
  - Audible import promoting a recommended record instead of skipping it;
  - Kindle likewise.
- **Feat:**
  - `library(mode: RECOMMENDED)` sections;
  - the `RECOMMENDED` status and the copied status;
  - `amazonUrl` null on non-recommended books;
  - the dashboard's `recommended`.
- **iOS:**
  - fixtures and `#Preview` for the Conseillés library, the recommended book page and the
    dashboard row;
  - screenshots of each for validation.
