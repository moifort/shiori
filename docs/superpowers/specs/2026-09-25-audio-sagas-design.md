# Audio sagas — design

## Problem

A saga's catalogue lists the volumes published in print. A reader who follows a saga on Audible
(the Bobiverse, in French) sees volumes that were never recorded offered as missing and addable,
and measures their progress against a spine that is not theirs: recordings trail the printed
books, sometimes by years, and some are never made.

## Decision

A saga heard and a saga read are two sagas. The Bobiverse on Audible and the Bobiverse in print are
two rows in the Series tab, each with its own volumes, progress, opinion and release dates.

### The key carries the format

`seriesKeyOf(name, author, format)` appends `--audio` for an `audiobook`; every other format keeps
today's key, so nothing moves for printed sagas. `seriesIdFor(id, format)` adds or strips the
suffix, and is applied wherever a book enters a saga:

- the Audible import, always audio;
- the scan, from the format read off the cover;
- `BookCommand.add`, which realigns the id with the format the reader finally saved;
- `BookCommand.edit`, where a book changing format moves to the other saga, and `membershipFor`
  only joins a saga of the same format by name.

The catalogue document gains no field: the format is read off the id, and GraphQL exposes
`Series.audio`.

### The audio catalogue

An audio id catalogues with a variant of the catalogue prompt that lists only the volumes recorded
or announced as audiobooks in the edition's language, searched on that language's Audible store.
A volume that exists only in print is not listed, so it is hidden.

The weekly release watch writes audiobook editions into an audio saga's catalogue and printed ones
into a printed saga's. Discover proposes each saga's own format only, so a reader holding both
sagas never sees one release twice.

### Migration 008

Every `audiobook` book in a saga moves to the suffixed id. A reader's saga opinion follows: moved
when the saga was all audio for that reader, copied to both when it mixed formats. Catalogues are
built on first opening; old watches go stale on their own.

### iOS

A `headphones` symbol beside an audio saga's name: Series tab rows, the saga screen, the progress
widget. The + on a missing volume already copies the format of an owned volume.
