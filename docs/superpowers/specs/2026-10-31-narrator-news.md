# Narrator news

The Actualités feed tells when a narrator the reader follows lends their voice to a recording
("Bernard Gabay prête sa voix à Fondation"), and the release calendar lists the ones to come.

## Who is followed

A narrator the reader holds two recordings of, or one rated four stars or more, or hearted —
the rule an author is followed by (`isFollowedAuthor`) — in the language most of those
recordings are in. Recordings only: a narrator reads nothing else.

## The watch

One shared document per narrator and language, `narrator-watches/{narratorKey}--{language}`,
holding no reference to any reader. One grounded Gemini call per watch
(`step: 'discovery-narrator-releases'`): every recording read by the narrator out in the last
ninety days, then those announced. A recording keeps its ASIN only once Audible's own catalogue
confirms it, as an author's works do. Looked up **every three months** by the hourly pass, after
the sagas and the authors, inside the same `MAX_LOOKS_PER_DAY` allowance.

## Cost

A grounded call bills about four Google searches (≈ €0.012 each once the 5,000 free a month are
spent) ≈ **€0.05 a call**.

- First run: one call per narrator followed, once. A reader following 10 narrators: 10 calls,
  ≈ €0.50, once.
- Steady state: one call per narrator every three months, so ≈ €0.017 a month for each,
  ≈ **€0.17 a month for 10 narrators**. Two readers following the same narrator share the call.
- Nothing is looked up when a reader opens the tab: `narratorNews` and `upcomingReleases` read the
  shared watches only.

## What is shown

- `narratorNews`: recordings out in the last 30 days that the reader does not hold, newest
  first — the feed's "prête sa voix à" row.
- `upcomingReleases`: recordings dated after today, `source: NARRATOR`, with the narrator's name —
  the calendar's "{name} prête sa voix" row. A recording without a date is neither.
