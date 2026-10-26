# Correcting a series page and an author page

## Why

The series and author pages are written by the model. When it is wrong, or leaves a gap, the
reader has no way to fix it, though they can on a book page ("Modifier", "Couverture"). This
gives the two pages the same corrections, with the same forms.

## What the reader gets

**Series page** — "Modifier" in the "…" menu opens a form in the style of `BookEditSheet`:

- **Name** of the series.
- **Type**: Livre, Bande dessinée, Comic, Manga. Saving rewrites the `format` of every book the
  reader holds of that edition. Audio is not offered, in either direction: a recording is
  another edition with its own catalogue, and switching from here would move the whole saga.
  A series heard shows no type field.
- **Résumé** (`description`), only when the edition has a stored catalogue.

**Author page** — "Modifier" (biography, nationality, birth year, death year), and
"Portrait", which works like "Couverture": the current face, what Wikipedia, Wikidata and Open
Library find for the name, and a field to paste an `https://` image address.

No AI call anywhere: the portrait sources are free. Nothing here is billed.

## Where each correction lands

The data model splits it:

| Field | Lands on | Seen by |
|---|---|---|
| Series type | the reader's books (`format`) | the reader |
| Series name, catalogued | `series/{id}` and every reader's volumes of that edition | everyone |
| Series name, no catalogue | the reader's volumes (`series.name`) | the reader |
| Series résumé | `series/{id}` | everyone |
| Author biography, nationality, years, portrait | `authors/{key}` | everyone |

A series name is a catalogue field even though books carry it: the series page and the Series
tab draw the catalogue's name, and cataloguing already writes it into every reader's volumes
(`BookCommand.nameSeries`). A rename on the reader's books alone would never show. The saga key
does not change with the name, so the volumes stay together.

The shared catalogues are corrected in place rather than overlaid per reader: these are facts
about the world, a fix serves every reader, and the Authors tab keeps reading every portrait in
one `getAll`. An overlay would double those reads and add a merge to maintain.

### Corrections are never overwritten

`Series` and `Author` gain `corrected?: Field[]`, the fields a reader set by hand. Every writer
of a catalogue keeps a corrected field's stored value:

- `SeriesCommand.catalogue` (scan, series screen, refresh) keeps `name` and `description`, and
  the scan then names the books after the stored, corrected name.
- `AuthorCommand.catalogueFromWeb` keeps the corrected biography, nationality, years, portrait.
- `AuthorCommand.seekPortrait` does not run on a corrected portrait.

### Every correction is logged

A flat collection `catalogue-corrections`, one document per correction: `userId`, the target
(`series` or `author` and its id), the field, the value before and after, the date. It sits
apart from the catalogues, which name no reader, and lets an abusive edit be found and undone.
It is erased with the account, like author favourites.

### An author with no catalogue

An author the model never described (a miss) has no `authors/{key}` document. A correction
creates one holding only the corrected fields, with empty `series` and `books`. Nothing asks
the model about a miss again anyway, so nothing is lost.

A series edition with no catalogue offers no résumé: a document written for it would mark the
edition as catalogued and stop the model from ever listing its volumes.

## Non-goals

- The volume list (already "Nombre de tomes" and "Fusionner avec…").
- The series' author and the author's name: both come from the reader's books and are
  corrected on the book page.
- Genre (already propagated across a saga from the book page).
- Undoing a correction from the app: the log is for the maintainer.

## API

Two mutations, deprecating nothing:

- `correctSeries(seriesId, name?, format?, description?)` → `Series`. `NOT_FOUND` when the
  reader holds no volume of the edition; `BAD_USER_INPUT` for an audio format either way, or a
  résumé on an uncatalogued edition.
- `correctAuthor(key, biography?, nationality?, birthYear?, deathYear?, portraitUrl?)` →
  the author catalogue. `NOT_FOUND` when the reader holds no book of the author. A field
  absent is left alone; an empty string clears a text field.
- `authorPortraitChoices(key)` → the portraits Wikipedia, Wikidata and Open Library offer for
  the name, each with its source, the current one marked.

## Builder's latitude

Field order and copy in the forms, the empty and failure states of the portrait sheet, and
how the pages refresh after a save follow the book page's.
