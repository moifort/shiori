# "Les découvertes du mois" — design

## Problem

Découvrir shows what the reader already follows: sagas, awaited editions, prizes, friends'
hearts. Nothing in it reads the reader's own taste and says "you would like this", with the
reason.

## Evidence

On 2026-10-12 three real libraries (192, 369 and 101 books) were sent, one prompt each, to
Haiku, Sonnet, Opus and Gemini 3.1 Pro, and the four lists shown blind. All three readers found
every list worth having; one bought books from his within days. What the test taught:

- **Models invent books.** None did on the first library; on the second, Sonnet named two that
  do not exist (an Izzo, an Énard) and a third doubtful one. Suggestions must be checked.
- **Open Library is not a filter.** It missed real books on every run (*Le Cercle*, *Chrysalis*,
  *Scalped*, *Eichmann à Jérusalem*…). A book it cannot find is not rejected for that alone.
- **Models suggest books the reader holds.** Two on the second library, despite the prompt.
  The server, not the model, excludes them.
- **French titles are guessed.** For recent romantasy a model translated the English title
  itself (*The Bridge Kingdom* → *Le Pont des Tempêtes*). The title shown must come from a real
  edition, not the model.
- **The reason sells the book.** The "comme Gagner la guerre" line is what the readers quoted
  back.

## Decision

"Les découvertes d'octobre" — the month named — in Découvrir's Books summary, right under
"Bientôt disponible": five suggestions as a strip of bare covers, like the other lines. The
same five open the home page, also as bare covers. Each suggestion opens the standard book
page with why it was chosen. Every action on a suggestion — dismiss it, add it, await it in
French or in audio — removes it and lets the next one in.

Model: **Claude Sonnet**, through the Anthropic API. It was the reader's pick of the four,
blind, on his own library.

## Rules

1. **What the model reads.** The reader's library by tier, best first:
   - ♥ hearts, ★★★★★, ★★★★, ★★★, then ★–★★ "déçu";
   - a book ranks by its own heart or stars; a read volume with none borrows its saga's, as
     `lovedRank` already does. Sagas rated as a whole are listed apart under each tier ("Et
     ces séries, notées dans leur ensemble"), with how many volumes rank only through them;
   - a volume ranked apart from its saga keeps its own line (Hypérion ♥, Endymion ★★);
   - the dropped books and sagas, as what the reader does not like;
   - the last 100 dismissed suggestions, as "pas intéressé";
   - not sent: read books with no rank of their own or their saga's, the pile, the awaited
     editions. The server excludes those.

   Sagas collapse to one line, so a 192-book library is about 2,000 tokens and a library of
   any size is capped at 300 lines.
2. **What the model returns.** 20 suggestions, each: original title, author, format, a reason
   sentence citing a book of the library, the 2–3 word "comme …" line, and the referenced
   titles. The prompt adapts to the library's formats (audio, paper, comics, manga) and
   languages.
3. **Checked before shown.** A suggestion is dropped when:
   - the reader holds it, by shelf key against the whole library (any status);
   - they dismissed it, awaited it, or it is a later volume of a saga they follow;
   - neither Open Library nor Google Books knows the title and author.
4. **The queue.** The kept suggestions are stored in order, per reader. Découvrir shows the
   first five. Dismissing, adding or awaiting one removes it; the next one moves up. There is
   no refill: a month whose selection ran out shows the heading alone, "Prochaines découvertes
   en novembre", until the next month.
5. **A selection per month, made only from Découvrir.** The title names the month, so the
   selection is the month's. It is made when the reader opens Découvrir in a month that has
   none — `monthlyDiscoveries(lookUp: true)` — never twice a day, about a minute during which
   the line shows "Recherche de vos découvertes…" over five blank covers. The home page only
   reads what there is (`lookUp` left out): it shows nothing of a month Découvrir has not been
   opened in yet. A failed generation leaves the line empty and is tried again the next day.
6. **In the app's language.** The titles, the reasons and the "comme …" / "like …" line are
   written in the app's language (French or English, from `Accept-Language`), the French
   reasons addressing the reader as « tu ». The selection remembers its language: a reader who
   switches the app is given a new one, within the daily cap.
7. **Dismissal is forever.** "Pas intéressé" is stored per reader and never suggested again;
   the model is told the last 100.
8. **The references are the reader's own books.** A referenced title is matched back to the
   library and shown with its rank (heart, stars, or "série" when the rank is the saga's). A
   reference that matches nothing is dropped from the list, the sentence kept.

## iOS

- **Découvrir › Livres summary.** "Les découvertes d'octobre" (`Les découvertes de {mois}`,
  elided before a vowel: d'août, d'avril, d'octobre) between "Bientôt disponible" and "Prix
  littéraires", symbol `sparkles`, violet, line "D'après vos préférences". Five bare covers,
  no caption under them, as the other lines' strips. A cover opens the suggestion's page.
- **Home.** The same five as a `BookShelfSection` of covers, after "En cours", with no line
  under the covers — the only home shelf without one, so the section gains a caption-less
  form. The heading opens Découvrir, a cover the suggestion's page. Absent
  when the queue is empty, as "Nouveautés" is.
- **A suggestion's page is the standard book page** — `BookHeaderSection` with no tag above
  it, then the description and synopsis sections as on an award winner's page — with one
  section added, **Pourquoi ce livre**: the reason sentence, then each referenced book of the
  library with its rank (♥, ★, "série"), a tap opening the reader's own page of it.
- **Actions live in the "+" menu**, top right, as on every book page: Ajouter (to the pile,
  per format), Guetter la version française, Guetter la version audio, then Pas intéressé
  (red). Any of them closes the page and the suggestion leaves the line.

## Server

- Domain `suggestion` (or inside `discovery`): `suggestions/{userId}` holds the queue, the
  generation date and the library fingerprint; `suggestion-dismissals` holds what was refused,
  flat with its `userId`.
- `ANTHROPIC_API_KEY` as `NITRO_ANTHROPIC_KEY`; without it the line is absent and nothing else
  breaks, as APNs works today.
- Query `monthlyDiscoveries(format)` — the first five, generation triggered behind it when
  rule 5 allows. Mutation `dismissSuggestion(id)`. Adding and awaiting reuse `addBook` and
  `awaitScanned`, and remove the suggestion server-side.
- The page's description reuses `describeRelease`, which also gives the edition's real French
  title.

## Cost

Sonnet, at $3 / $15 per million tokens in / out. Measured on 2026-10-15 on a 192-book library:
4,172 tokens in, 6,863 out — the twenty reasons are the bulk — in 53 s, **$0.116 ≈ €0.10 per
generation**. Open Library and Google Books are free. The workspace "Shiori" on the Claude
Console caps the spend at $20 a month.

| | Generations | Cost |
|---|---|---|
| First look, per reader | 1 | €0.10 |
| Month, per reader who opens Découvrir | 1 | €0.10 |
| A reader who switches the app's language that month | +1 | €0.10 |
| 100 active readers, month | 100 | €10 |

A suggestion's page also calls `describeRelease` the first time anybody opens that book in that
language: one grounded Gemini call, ≈ 4 billed searches ≈ €0.05, paid once and shared, refused
to a reader whose scan allowance is spent. A reader opening five new suggestions a week adds
≈ €1 a month at most, less as readers share books.

No pass over existing readers: the first generation runs on the first look at Découvrir.

## Privacy

The library leaves for Anthropic. The App Store privacy answers and the privacy policy name it
before release, beside Google's Gemini.

## Testing

- **Unit:** the tiered digest (own rank, saga's rank borrowed only once read, a volume ranked
  apart, the 300-line cap); the shelf-key exclusion; the reference matching; regeneration
  rule 5 and its daily cap.
- **Int:** a generation against a stubbed model — owned, dismissed and invented books dropped,
  the queue stored; dismiss and add each moving the queue up; reads budgeted.
- **Feat:** `suggestions` and `dismissSuggestion` through the schema.
- **iOS:** fixtures and `#Preview` for the strip and the page; screenshots for
  validation.
