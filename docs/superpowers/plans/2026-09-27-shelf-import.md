# Shelf Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a Premium reader photograph a shelf of spines, or covers laid out on the floor, tick
the books found in a checklist, and add them all in one go.

**Architecture:** One new ungrounded Gemini call (`detectBooks`) reads every book in the photo
with its position, and flags the ones the reader owns. It spends nothing. Each ticked book then
goes through `describeDetectedBook`, which is the cover scan minus its vision step: grounded
enrichment, published cover, saga and author catalogues, and one scan metered. The app saves it
with the existing `addBook`. On iOS a separate `ShelfImportView` flow sits beside `ScanView`.

**Tech Stack:** Nitro + bun, Pothos GraphQL, Gemini REST (`generate` in `server/domain/scan/gemini.ts`),
fake Firestore for tests; SwiftUI (iOS 26), Apollo iOS codegen.

**Spec:** [docs/superpowers/specs/2026-09-27-shelf-import-design.md](../specs/2026-09-27-shelf-import-design.md)

## Global Constraints

- Detection is **Premium only**: a free account gets `PREMIUM_REQUIRED` before any model call.
- Detection **spends nothing** but is refused with `QUOTA_EXHAUSTED` once the allowance is used up.
- Each ticked book spends **one scan**, only on success, never cached.
- **At most 30 books** per photo (`MAX_DETECTED_BOOKS = 30`), in reading order: left to right, top to bottom.
- Box coordinates exposed as `x`, `y`, `width`, `height` in `0...1` of the photo; Gemini's `box_2d` never leaves the server.
- The photo is sent at **2000 px** on the long side, JPEG quality **0.7**; crops are cut on device and never uploaded.
- Adding runs **3 books at a time**.
- English for code, comments, commits; French only for on-screen text.
- Never `console.*`: `createLogger(tag)`, constant message, context apart.
- Biome: spaces, single quotes, no semicolons, width 100.
- Test suffixes run separately (`mock.module` leaks across files): run `bun test <file>` per file.
- Never touch `CHANGELOG.md` / `CHANGELOG.fr.md`. Never push.
- Before each server commit: `bunx nitro prepare && bunx tsc --noEmit`, the touched test files, `bunx biome check`.

---

### Task 1: Box and reading-order rules

**Files:**
- Modify: `server/domain/scan/types.ts` (append)
- Create: `server/domain/scan/business-rules.ts`
- Test: `server/domain/scan/business-rules.unit.test.ts`

**Interfaces:**
- Produces:
  - `type DetectedBox = { x: number; y: number; width: number; height: number }`
  - `type SeenOnShelf = { title?: BookTitle; authors: AuthorName[]; publisher?: Publisher; language?: BookLanguage; format?: BookFormat; seriesName?: SeriesName; volume?: VolumeNumber; box: DetectedBox }`
  - `type DetectedBook = SeenOnShelf & { owned: boolean }`
  - `MAX_DETECTED_BOOKS: 30`
  - `boxOf(box2d: readonly number[]): DetectedBox | undefined`
  - `inReadingOrder<T extends { box: DetectedBox }>(books: readonly T[]): T[]`

- [ ] **Step 1: Add the types**

Append to `server/domain/scan/types.ts`:

```ts
/** Where a book sits in the reader's photo, each side a fraction of the photo:
 *  `x` and `y` are its top-left corner, `0...1` from the left and the top. */
export type DetectedBox = { x: number; y: number; width: number; height: number }

/** One book read off a shelf photo: only what its spine or cover prints, and
 *  where it is. `title` is absent when the model could not read it — the
 *  reader types it on the checklist. */
export type SeenOnShelf = {
  title?: BookTitle
  authors: AuthorName[]
  publisher?: Publisher
  language?: BookLanguage
  format?: BookFormat
  seriesName?: SeriesName
  volume?: VolumeNumber
  box: DetectedBox
}

/** A book of the photo as the checklist shows it: whether the reader already
 *  owns it decides whether it comes ticked. */
export type DetectedBook = SeenOnShelf & { owned: boolean }
```

`SeriesName` and `VolumeNumber` are already imported at the top of the file with `SeriesId`; `BookFormat`, `BookLanguage`, `Publisher` from `~/domain/book/types` are too.

- [ ] **Step 2: Write the failing test**

Create `server/domain/scan/business-rules.unit.test.ts`:

```ts
import { describe, expect, test } from 'bun:test'
import { boxOf, inReadingOrder } from '~/domain/scan/business-rules'

describe('boxOf', () => {
  test('turns Gemini’s [ymin, xmin, ymax, xmax] on 0–1000 into fractions of the photo', () => {
    expect(boxOf([100, 200, 900, 250])).toEqual({ x: 0.2, y: 0.1, width: 0.05, height: 0.8 })
  })

  test('clamps a corner the model drew outside the photo', () => {
    expect(boxOf([-20, 950, 500, 1040])).toEqual({ x: 0.95, y: 0, width: 0.05, height: 0.5 })
  })

  test('refuses a box that is not four numbers, or has no area', () => {
    expect(boxOf([1, 2, 3])).toBeUndefined()
    expect(boxOf([100, 200, 100, 300])).toBeUndefined()
    expect(boxOf([100, 300, 200, 300])).toBeUndefined()
    expect(boxOf([100, Number.NaN, 200, 300])).toBeUndefined()
  })
})

describe('inReadingOrder', () => {
  const at = (id: string, x: number, y: number, width = 0.1, height = 0.3) => ({
    id,
    box: { x, y, width, height },
  })

  test('reads a shelf of spines left to right, whatever their heights', () => {
    const books = [at('c', 0.5, 0.12, 0.05, 0.7), at('a', 0.1, 0.1, 0.05, 0.8), at('b', 0.3, 0.2, 0.05, 0.6)]
    expect(inReadingOrder(books).map(({ id }) => id)).toEqual(['a', 'b', 'c'])
  })

  test('reads two shelves top to bottom, each left to right', () => {
    const books = [at('d', 0.6, 0.55), at('b', 0.6, 0.05), at('c', 0.1, 0.6), at('a', 0.1, 0.1)]
    expect(inReadingOrder(books).map(({ id }) => id)).toEqual(['a', 'b', 'c', 'd'])
  })
})
```

- [ ] **Step 3: Run it to verify it fails**

Run: `cd server && bun test domain/scan/business-rules.unit.test.ts`
Expected: FAIL, cannot find module `~/domain/scan/business-rules`.

- [ ] **Step 4: Implement**

Create `server/domain/scan/business-rules.ts`:

```ts
import type { DetectedBox } from '~/domain/scan/types'

/** How many books one photo answers at most. Past thirty the spines are too
 *  thin to read anyway, and the checklist is longer than anyone ticks through. */
export const MAX_DETECTED_BOOKS = 30

/** Gemini's `box_2d` — `[ymin, xmin, ymax, xmax]` on a 0–1000 grid — as the
 *  fractions the app crops with. Converted here, once, so no client ever learns
 *  the model's convention. A box without area is no box: the book is dropped
 *  rather than drawn as a dot. */
export const boxOf = (box2d: readonly number[]): DetectedBox | undefined => {
  if (box2d.length !== 4 || box2d.some((value) => !Number.isFinite(value))) return undefined
  const [ymin, xmin, ymax, xmax] = box2d.map((value) => Math.min(Math.max(value, 0), 1000) / 1000)
  if (xmax <= xmin || ymax <= ymin) return undefined
  return {
    x: rounded(xmin),
    y: rounded(ymin),
    width: rounded(xmax - xmin),
    height: rounded(ymax - ymin),
  }
}

/** Four decimals: a tenth of a pixel on a 2000 px photo, and no float noise
 *  (0.25 − 0.2 is 0.04999999999999999) shipped through the API. */
const rounded = (value: number) => Math.round(value * 10_000) / 10_000

/** Left to right, top to bottom, as the reader's eye goes along a bookcase.
 *  A book joins the row of the book above it when its vertical centre falls
 *  within that row's first book: spines of uneven height stay on one shelf. */
export const inReadingOrder = <T extends { box: DetectedBox }>(books: readonly T[]): T[] => {
  const rows: T[][] = []
  for (const book of [...books].sort((a, b) => a.box.y - b.box.y)) {
    const row = rows.at(-1)
    const centre = book.box.y + book.box.height / 2
    if (row && centre < row[0].box.y + row[0].box.height) row.push(book)
    else rows.push([book])
  }
  return rows.flatMap((row) => row.sort((a, b) => a.box.x - b.box.x))
}
```

- [ ] **Step 5: Run it to verify it passes**

Run: `cd server && bun test domain/scan/business-rules.unit.test.ts`
Expected: PASS, 5 tests.

- [ ] **Step 6: Commit**

```bash
git add server/domain/scan/types.ts server/domain/scan/business-rules.ts server/domain/scan/business-rules.unit.test.ts
git commit -m "feat(scan): place a book found in a shelf photo, in reading order"
```

---

### Task 2: Detecting the books of a photo

**Files:**
- Modify: `server/domain/scan/schemas.ts` (append `SHELF_SCHEMA`)
- Modify: `server/domain/scan/prompts.ts` (append `shelfPrompt`)
- Modify: `server/domain/scan/stub.ts` (append `STUBBED_SHELF`)
- Modify: `server/domain/scan/command.ts` (add `ScanCommand.detectBooks`)
- Modify: `server/domain/admin/command.ts` (add `AdminCommand.recordShelfUsage`)
- Modify: `server/domain/scan/use-case.ts` (add `ShelfOutcome`, `ScanUseCase.detectBooks`)
- Test: `server/domain/scan/use-case.int.test.ts`

**Interfaces:**
- Consumes: `SeenOnShelf`, `DetectedBook`, `boxOf`, `inReadingOrder`, `MAX_DETECTED_BOOKS` (Task 1)
- Produces:
  - `ScanCommand.detectBooks(image: Buffer, language: ScanLanguage): Promise<{ books: SeenOnShelf[]; usage?: AiStepUsage }>`
  - `type ShelfOutcome = DetectedBook[] | 'premium-required' | 'quota-exhausted' | { failed: string }`
  - `ScanUseCase.detectBooks(userId: UserId, image: Buffer, language: ScanLanguage): Promise<ShelfOutcome>`

- [ ] **Step 1: Write the failing tests**

In `server/domain/scan/use-case.int.test.ts`, make the premium list mutable. Replace the config mock:

```ts
let premiumUserIds: string[] = []
mock.module('~/system/config', () => ({
  config: () => ({ googleApiKey: 'test-key', premiumUserIds }),
}))
```

add `premiumUserIds = []` to the `beforeEach`, and add these imports next to the other dynamic ones:

```ts
const { BookCommand } = await import('~/domain/book/command')
const { AuthorName } = await import('~/domain/shared/primitives')
```

(merge `AuthorName` into the existing `BookTitle` import line). Then append:

```ts
describe('a shelf photo', () => {
  const shelf = {
    books: [
      { box_2d: [100, 500, 900, 560], title: 'Fondation', authors: ['Isaac Asimov'] },
      { box_2d: [120, 100, 880, 150], title: 'Dune', authors: ['Frank Herbert'], volumeNumber: 1 },
      { box_2d: [110, 300, 900, 340], title: null, authors: [] },
      { box_2d: [0, 0, 0, 0], title: 'Sans cadre', authors: [] },
    ],
  }

  test('answers each book in reading order, owned ones flagged, and spends nothing', async () => {
    premiumUserIds = [reader]
    await BookCommand.add(reader, {
      title: BookTitle('Fondation'),
      authors: [AuthorName('Isaac Asimov')],
    })
    answers = [shelf]

    const outcome = await ScanUseCase.detectBooks(reader, image, 'fr')

    expect(outcome).toMatchObject([
      { title: 'Dune', authors: ['Frank Herbert'], volume: 1, owned: false },
      { authors: [], owned: false, box: { x: 0.3, y: 0.11, width: 0.04, height: 0.79 } },
      { title: 'Fondation', owned: true },
    ])
    expect((outcome as unknown[])[1]).not.toHaveProperty('title')
    expect(calls).toEqual(['shelf'])
    expect(spent()).toBe(0)
    expect(fake.data('ai-usage', monthOf(new Date()))).toMatchObject({
      scans: 0,
      vision: { promptTokens: 10 },
    })
  })

  test('is refused to a free account before the model is called', async () => {
    expect(await ScanUseCase.detectBooks(reader, image, 'fr')).toBe('premium-required')
    expect(calls).toHaveLength(0)
  })

  test('is refused once the allowance is used up', async () => {
    premiumUserIds = [reader]
    fake.seed('ai-quotas', quotaDoc(), { userId: reader, month: monthOf(new Date()), scans: 100 })

    expect(await ScanUseCase.detectBooks(reader, image, 'fr')).toBe('quota-exhausted')
    expect(calls).toHaveLength(0)
  })

  test('keeps the thirty books read first', async () => {
    premiumUserIds = [reader]
    answers = [
      {
        books: Array.from({ length: 35 }, (_, index) => ({
          box_2d: [100, index * 28, 900, index * 28 + 20],
          title: `Livre ${index}`,
          authors: [],
        })),
      },
    ]

    const outcome = (await ScanUseCase.detectBooks(reader, image, 'fr')) as { title: string }[]

    expect(outcome).toHaveLength(30)
    expect(outcome[29].title).toBe('Livre 29')
  })

  test('says why the model failed', async () => {
    premiumUserIds = [reader]
    answers = [new Error('model unavailable')]

    expect(await ScanUseCase.detectBooks(reader, image, 'fr')).toEqual({
      failed: 'model unavailable',
    })
  })
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd server && bun test domain/scan/use-case.int.test.ts`
Expected: FAIL, `ScanUseCase.detectBooks is not a function`. The existing tests still pass.

- [ ] **Step 3: Add the schema**

Append to `server/domain/scan/schemas.ts`:

```ts
/** A shelf photo: every book in it, each with its frame. Ungrounded like the
 *  cover's vision step, whose field descriptions it reuses — a spine prints the
 *  same things a cover does, only fewer of them. */
export const SHELF_SCHEMA = {
  type: 'object',
  properties: {
    books: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          box_2d: {
            type: 'array',
            items: { type: 'integer' },
            description: 'Cadre du livre dans la photo : [ymin, xmin, ymax, xmax] de 0 à 1000',
          },
          title: {
            type: 'string',
            nullable: true,
            description: 'Titre tel qu’imprimé, null si illisible',
          },
          authors: VISION_SCHEMA.properties.authors,
          format: VISION_SCHEMA.properties.format,
          publisher: VISION_SCHEMA.properties.publisher,
          language: VISION_SCHEMA.properties.language,
          seriesName: VISION_SCHEMA.properties.seriesName,
          volumeNumber: VISION_SCHEMA.properties.volumeNumber,
        },
        required: ['box_2d', 'authors'],
        propertyOrdering: [
          'box_2d',
          'title',
          'authors',
          'format',
          'publisher',
          'language',
          'seriesName',
          'volumeNumber',
        ],
      },
    },
  },
  required: ['books'],
} as const
```

- [ ] **Step 4: Add the prompt**

Append to `server/domain/scan/prompts.ts`:

```ts
/** A whole shelf in one photo: spines side by side, or covers laid out flat.
 *  As narrow as `visionPrompt` — only what is printed — and just as honest about
 *  what it cannot read: an unreadable spine is still a book, framed with no
 *  title, so the reader can name it rather than lose it. */
export const shelfPrompt = (language: ScanLanguage) =>
  `Cette photo montre plusieurs livres : des tranches alignées sur une étagère, ou des couvertures posées à plat. Repère CHAQUE livre visible et relève uniquement ce qui y est IMPRIMÉ.

Pour chaque livre :
- box_2d : le cadre qui entoure ce livre seul (sa tranche ou sa couverture), [ymin, xmin, ymax, xmax] de 0 à 1000.
- title : le titre tel qu'imprimé, sans le compléter ni le corriger. Mets null si tu ne peux pas le lire avec certitude — ne devine jamais un titre.
- authors : le ou les auteurs imprimés, hors traducteur, préfacier et illustrateur. Liste vide si aucun n'est lisible.
- format : même règle que pour une couverture ('manga', 'bande-dessinee', 'comic', 'audiobook', 'ebook', 'book'), null si tu hésites.
- publisher : l'éditeur si son nom ou son logo est lisible, sinon null.
- language : la langue de CETTE édition d'après les textes imprimés, null si rien ne permet de trancher.
- seriesName et volumeNumber : seulement si la tranche ou la couverture les imprime (« Tome 3 », un numéro en bas de tranche). Sinon null.

Un livre partiellement caché compte s'il est identifiable. Un objet qui n'est pas un livre (serre-livres, bibelot, boîte) ne compte pas. Ne répète pas un livre.

N'INVENTE RIEN. Toutes les valeurs textuelles doivent être en ${LANGUAGE_NAMES[language]}, sauf les titres et auteurs, recopiés tels qu'imprimés.`
```

- [ ] **Step 5: Add the stub**

Append to `server/domain/scan/stub.ts` (import `DetectedBox`-free — the stub holds `SeenOnShelf`):

```ts
/** What a stubbed shelf photo answers: two books of one saga and a spine the
 *  model could not read, so the checklist shows all three kinds of row. */
export const STUBBED_SHELF: SeenOnShelf[] = [
  {
    title: BookTitle('Le Nom du vent'),
    authors: [AuthorName('Patrick Rothfuss')],
    seriesName: SeriesName('Chronique du tueur de roi'),
    volume: VolumeNumber(1),
    box: { x: 0.1, y: 0.1, width: 0.08, height: 0.8 },
  },
  {
    title: BookTitle('La Peur du sage'),
    authors: [AuthorName('Patrick Rothfuss')],
    seriesName: SeriesName('Chronique du tueur de roi'),
    volume: VolumeNumber(2),
    box: { x: 0.2, y: 0.12, width: 0.09, height: 0.78 },
  },
  { authors: [], box: { x: 0.32, y: 0.1, width: 0.06, height: 0.8 } },
]
```

with `import type { ScanResult, SeenOnShelf } from '~/domain/scan/types'` replacing the existing `ScanResult` type import.

- [ ] **Step 6: Add the command**

In `server/domain/scan/command.ts`:
- import `boxOf`, `inReadingOrder`, `MAX_DETECTED_BOOKS` from `~/domain/scan/business-rules`;
- add `shelfPrompt` to the prompts import, `SHELF_SCHEMA` to the schemas import, `STUBBED_SHELF` to the stub import, `SeenOnShelf` to the types import.

Add the output type beside `VisionOutput`:

```ts
type ShelfOutput = {
  books?: {
    box_2d?: number[]
    title?: string | null
    authors?: string[]
    format?: string | null
    publisher?: string | null
    language?: string | null
    seriesName?: string | null
    volumeNumber?: number | null
  }[]
}
```

Inside `namespace ScanCommand`, after `lookUpEdition`:

```ts
  /** Every book of a shelf photo, read as the cover's first step reads one:
   *  ungrounded, printed text only. Nothing is enriched here — the reader
   *  first says which books they want, and only those are paid for. */
  export const detectBooks = async (
    image: Buffer,
    language: ScanLanguage,
  ): Promise<{ books: SeenOnShelf[]; usage?: AiStepUsage }> => {
    if (import.meta.dev && config().scanStub) return { books: STUBBED_SHELF }

    const { value, usage } = await generate<ShelfOutput>({
      step: 'shelf',
      parts: [
        { inline_data: { mime_type: 'image/jpeg', data: image.toString('base64') } },
        { text: shelfPrompt(language) },
      ],
      responseSchema: SHELF_SCHEMA,
    })
    const books = (value.books ?? []).map(parsedShelfBook).filter(isPresent)
    return { books: inReadingOrder(books).slice(0, MAX_DETECTED_BOOKS), usage }
  }

  /** A book without a frame cannot be cropped or pointed at, so it is dropped;
   *  a book without a title is kept, for the reader to name. */
  const parsedShelfBook = (
    raw: NonNullable<ShelfOutput['books']>[number],
  ): SeenOnShelf | undefined => {
    const box = boxOf(raw.box_2d ?? [])
    if (!box) return undefined
    const book: SeenOnShelf = {
      title: optional(raw.title, BookTitle),
      authors: parsedAuthors(raw.authors ?? []),
      format: optional(raw.format, BookFormatValue),
      publisher: optional(raw.publisher, Publisher),
      language: optional(raw.language, BookLanguageValue),
      seriesName: optional(raw.seriesName, SeriesName),
      volume: optional(raw.volumeNumber, VolumeNumber),
      box,
    }
    // A field the spine did not print is absent, not present-and-undefined:
    // the tests and the GraphQL layer both read "no title" as a missing key.
    return Object.fromEntries(
      Object.entries(book).filter(([, value]) => value !== undefined),
    ) as SeenOnShelf
  }
```

`optional` (from `~/utils/input`) returns `undefined` for `null`, `''` and anything the constructor rejects.

- [ ] **Step 7: Record the usage**

In `server/domain/admin/command.ts`, after `recordTitleSearchUsage`:

```ts
  // A shelf photo read for its books. No scan is spent on it — each book the
  // reader keeps is its own scan — so only the tokens move, on the vision line,
  // since it is the same kind of call. Telemetry like the above.
  export const recordShelfUsage = async (vision: AiStepUsage) => {
    await repository.recordUsage(monthOf(new Date()), { scans: 0, cacheHits: 0, vision })
  }
```

- [ ] **Step 8: Add the use case**

In `server/domain/scan/use-case.ts`, import `BookQuery` from `~/domain/book/query`, `shelfKeyOf` from `~/domain/book/business-rules`, and `DetectedBook` from the scan types. After `ScanOutcome`:

```ts
/** What a shelf photo answers: its books, or why there are none. */
export type ShelfOutcome = DetectedBook[] | 'premium-required' | 'quota-exhausted' | { failed: string }
```

Inside `namespace ScanUseCase`:

```ts
  /** The books of a shelf photo, each flagged when the reader already owns it.
   *  Premium only, and asked before anything else so a free reader is told
   *  what would open it rather than that they ran out. Spends nothing — every
   *  book kept is its own scan — but refused once the allowance is used up,
   *  since those scans would be. */
  export const detectBooks = async (
    userId: UserId,
    image: Buffer,
    language: ScanLanguage,
  ): Promise<ShelfOutcome> => {
    const { plan, quota, credit } = await QuotaQuery.allowanceOf(userId)
    if (plan !== 'premium') return 'premium-required'
    if (exhausted(plan, quota, credit)) return 'quota-exhausted'
    try {
      const [{ books, usage }, owned] = await Promise.all([
        ScanCommand.detectBooks(image, language),
        BookQuery.shelfKeys(userId),
      ])
      if (usage)
        await AdminCommand.recordShelfUsage(usage).catch((error) =>
          logger.warn('AI usage not recorded', { error }),
        )
      return books.map((book) => ({
        ...book,
        owned: book.title !== undefined && owned.has(shelfKeyOf(book.title, book.authors[0])),
      }))
    } catch (error) {
      logger.error('shelf detection failed', { error, userId })
      return { failed: error instanceof Error ? error.message : 'Detection failed' }
    }
  }
```

- [ ] **Step 9: Run the tests to verify they pass**

Run: `cd server && bun test domain/scan/use-case.int.test.ts && bun test domain/scan/business-rules.unit.test.ts`
Expected: PASS. If the owned test fails on `owned: true`, check that `BookCommand.add` stored `authors[0]` as `Isaac Asimov` and that `shelfKeyOf` slugs both sides identically — do not loosen the assertion.

- [ ] **Step 10: Typecheck, lint, commit**

```bash
cd server && bunx nitro prepare && bunx tsc --noEmit && bunx biome check
git add server/domain/scan server/domain/admin/command.ts
git commit -m "feat(scan): read every book of a shelf photo, for Premium readers"
```

---

### Task 3: Describing a ticked book

**Files:**
- Modify: `server/domain/scan/command.ts` (add `ScanCommand.describeDetected`)
- Modify: `server/domain/scan/use-case.ts` (add `ScanUseCase.describeDetected`)
- Test: `server/domain/scan/use-case.int.test.ts`

**Interfaces:**
- Consumes: `metered`, `enrich`, `coverOf`, `catalogueWhatOpensNext` (existing, private to their files)
- Produces:
  - `ScanCommand.describeDetected(seen: ScanResult, language: ScanLanguage): Promise<{ result: ScanResult; usage: ScanUsage }>`
  - `ScanUseCase.describeDetected(userId: UserId, seen: ScanResult, language: ScanLanguage): Promise<ScanOutcome>`

- [ ] **Step 1: Write the failing tests**

Append to `server/domain/scan/use-case.int.test.ts`:

```ts
describe('a book ticked on a shelf photo', () => {
  const ticked = {
    recognized: true,
    title: BookTitle('Le Nom du vent'),
    authors: [AuthorName('Patrick Rothfuss')],
    subgenres: [],
  }

  test('is enriched and its saga catalogued as a scanned cover is, for one scan', async () => {
    answers = [
      { ...anEnrichment, seriesName: 'Chronique du tueur de roi', volumeNumber: 1, volumeKind: 'main' },
      {
        name: 'Chronique du tueur de roi',
        author: 'Patrick Rothfuss',
        volumes: [{ kind: 'main', number: 1, title: 'Le Nom du vent' }],
      },
    ]

    const outcome = await ScanUseCase.describeDetected(reader, ticked, 'fr')

    expect(outcome).toMatchObject({
      recognized: true,
      title: 'Le Nom du vent',
      series: { name: 'Chronique du tueur de roi', volume: 1 },
    })
    expect(calls).toEqual(['enrichment', 'catalogue'])
    expect(spent()).toBe(1)
  })

  test('spends nothing when the model fails', async () => {
    answers = [new Error('model unavailable')]

    expect(await ScanUseCase.describeDetected(reader, ticked, 'fr')).toEqual({
      failed: 'model unavailable',
    })
    expect(spent()).toBe(0)
  })
})
```

`'catalogue'` is the step name `catalogueSeries` passes to `generate` (`command.ts:424`); the `'author'` step is answered by the mock without being recorded in `calls`.

- [ ] **Step 2: Run them to verify they fail**

Run: `cd server && bun test domain/scan/use-case.int.test.ts`
Expected: FAIL, `ScanUseCase.describeDetected is not a function`.

- [ ] **Step 3: Implement the command**

In `server/domain/scan/command.ts`, after `detectBooks`:

```ts
  /** A book ticked on a shelf photo, described as a scanned cover is once it
   *  was read: the grounded step, the published cover, and the saga's and
   *  author's pages when nobody built them — what the reader opens next is the
   *  same whether the book came alone or with its shelf. Unlike
   *  `lookUpEdition`, whose saga the release watch already knows. Never cached:
   *  there is no image of this one book to hash. */
  export const describeDetected = async (
    seen: ScanResult,
    language: ScanLanguage,
  ): Promise<{ result: ScanResult; usage: ScanUsage }> => {
    if (import.meta.dev && config().scanStub) return { result: STUBBED_SCAN, usage: {} }

    const { result: enriched, regularEdition, usage: enrichment } = await enrich(seen, language)
    const result = { ...enriched, coverUrl: await coverOf(enriched.isbn13, regularEdition) }
    const { catalogue, author } = await catalogueWhatOpensNext(result, language, true)
    return { result, usage: { enrichment, catalogue, author } }
  }
```

- [ ] **Step 4: Implement the use case**

In `server/domain/scan/use-case.ts`, after `lookUpEdition`:

```ts
  /** Describe a book the reader ticked on a shelf photo. Never cached, so it
   *  always spends one scan — and only once the model answered. */
  export const describeDetected = (userId: UserId, seen: ScanResult, language: ScanLanguage) =>
    metered(userId, 'detected book lookup failed', async () => ({
      ...(await ScanCommand.describeDetected(seen, language)),
      cacheHit: false,
    }))
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd server && bun test domain/scan/use-case.int.test.ts`
Expected: PASS.

- [ ] **Step 6: Typecheck, lint, commit**

```bash
cd server && bunx nitro prepare && bunx tsc --noEmit && bunx biome check
git add server/domain/scan
git commit -m "feat(scan): describe a book ticked on a shelf photo as a scanned cover"
```

---

### Task 4: GraphQL surface

**Files:**
- Modify: `server/domain/scan/infrastructure/graphql/types.ts` (add `DetectedBoxType`, `DetectedBookType`)
- Modify: `server/domain/scan/infrastructure/graphql/mutations.ts` (add `DetectedBookInput`, `detectBooks`, `describeDetectedBook`)
- Modify: `shared/schema.graphql` (generated)
- Test: `server/domain/scan/infrastructure/graphql/mutations.feat.test.ts`

**Interfaces:**
- Consumes: `ScanUseCase.detectBooks`, `ScanUseCase.describeDetected`, `DetectedBook`, `DetectedBox`
- Produces (schema):
  - `detectBooks(imageBase64: String!): [DetectedBook!]!`
  - `describeDetectedBook(book: DetectedBookInput!): ScanResult`
  - `type DetectedBook { title: BookTitle, authors: [AuthorName!]!, publisher: Publisher, language: BookLanguage, format: BookFormat, seriesName: SeriesName, volume: VolumeNumber, box: DetectedBox!, owned: Boolean! }`
  - `type DetectedBox { x: Float!, y: Float!, width: Float!, height: Float! }`
  - `input DetectedBookInput { title: BookTitle!, authors: [AuthorName!]!, publisher: Publisher, language: BookLanguage, format: BookFormat }`
  - error codes `PREMIUM_REQUIRED`, `QUOTA_EXHAUSTED`, `IMAGE_TOO_LARGE`, `SCAN_FAILED`

- [ ] **Step 1: Write the failing tests**

In `mutations.feat.test.ts`, make the config mock read a mutable `premiumUserIds` exactly as in Task 2 Step 1 (reset in `beforeEach`). `describeDetectedBook` builds the author's page as a scan does, so the Gemini mock must answer that step without consuming the queue — add at the top of its `generate`:

```ts
    if (step === 'author')
      return {
        value: { series: [], books: [] },
        usage: { promptTokens: 7, outputTokens: 3, thinkingTokens: 0, searches: 1 },
      }
```

Then append:

```ts
const detectBooks = () =>
  graphql({
    schema,
    source: `mutation($image: String!) {
      detectBooks(imageBase64: $image) {
        title authors volume owned box { x y width height }
      }
    }`,
    variableValues: { image: Buffer.from('a shelf').toString('base64') },
    contextValue: { event: undefined, userId },
  })

describe('detectBooks', () => {
  test('answers the books of the photo with their frames', async () => {
    premiumUserIds = [userId]
    answers = [
      { books: [{ box_2d: [100, 200, 900, 250], title: 'Dune', authors: ['Frank Herbert'] }] },
    ]

    const result = await detectBooks()

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      detectBooks: [
        {
          title: 'Dune',
          authors: ['Frank Herbert'],
          volume: null,
          owned: false,
          box: { x: 0.2, y: 0.1, width: 0.05, height: 0.8 },
        },
      ],
    })
  })

  test('is refused to a free account with PREMIUM_REQUIRED', async () => {
    const result = await detectBooks()

    expect(result.errors?.[0]?.extensions?.code).toBe('PREMIUM_REQUIRED')
  })
})

describe('describeDetectedBook', () => {
  test('answers a record to review and spends one scan', async () => {
    answers = [{ title: 'Dune', authors: ['Frank Herbert'], subgenres: [] }]

    const result = await graphql({
      schema,
      source: `mutation($book: DetectedBookInput!) {
        describeDetectedBook(book: $book) { recognized title authors format }
      }`,
      variableValues: { book: { title: 'Dune', authors: ['Frank Herbert'], format: 'BOOK' } },
      contextValue: { event: undefined, userId },
    })

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      describeDetectedBook: {
        recognized: true,
        title: 'Dune',
        authors: ['Frank Herbert'],
        format: 'BOOK',
      },
    })
    const month = fake.data('ai-quotas', `${userId}_${monthOf(new Date())}`) as { scans: number }
    expect(month.scans).toBe(1)
  })
})
```

If the enum value for a plain book is not `BOOK`, read it from `shared/schema.graphql` (`enum BookFormat`) and use that.

- [ ] **Step 2: Run them to verify they fail**

Run: `cd server && bun test domain/scan/infrastructure/graphql/mutations.feat.test.ts`
Expected: FAIL, `Cannot query field "detectBooks" on type "Mutation"`.

- [ ] **Step 3: Add the object types**

Append to `server/domain/scan/infrastructure/graphql/types.ts` (add `DetectedBook`, `DetectedBox` to the scan types import):

```ts
const DetectedBoxType = builder.objectRef<DetectedBox>('DetectedBox').implement({
  description:
    'Where a book sits in the photo, each side a fraction of it: `x` and `y` are the ' +
    'top-left corner, from 0 at the left and top edges to 1 at the right and bottom. ' +
    'Multiply by the size of the photo that was sent to crop the book out of it.',
  fields: (t) => ({
    x: t.exposeFloat('x'),
    y: t.exposeFloat('y'),
    width: t.exposeFloat('width'),
    height: t.exposeFloat('height'),
  }),
})

export const DetectedBookType = builder.objectRef<DetectedBook>('DetectedBook').implement({
  description:
    'One book found in a shelf photo, as printed on its spine or cover — nothing is ' +
    'looked up yet. The reader ticks the ones to keep, and `describeDetectedBook` ' +
    'builds the record of each.',
  fields: (t) => ({
    title: t.field({
      type: 'BookTitle',
      nullable: true,
      description: 'Null when the spine could not be read: the reader types it.',
      resolve: (book) => book.title ?? null,
    }),
    authors: t.field({ type: ['AuthorName'], resolve: (book) => book.authors }),
    publisher: t.field({
      type: 'Publisher',
      nullable: true,
      resolve: (book) => book.publisher ?? null,
    }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      resolve: (book) => book.language ?? null,
    }),
    format: t.field({
      type: BookFormatEnum,
      nullable: true,
      resolve: (book) => book.format ?? null,
    }),
    seriesName: t.field({
      type: 'SeriesName',
      nullable: true,
      description: 'Only when printed on the book.',
      resolve: (book) => book.seriesName ?? null,
    }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      resolve: (book) => book.volume ?? null,
    }),
    box: t.field({ type: DetectedBoxType, resolve: (book) => book.box }),
    owned: t.boolean({
      description:
        'The reader already has this story, in any edition — the same title by the ' +
        'same first author. Such a book comes unticked. Always false without a title.',
      resolve: (book) => book.owned,
    }),
  }),
})
```

- [ ] **Step 4: Add the input and mutations**

In `server/domain/scan/infrastructure/graphql/mutations.ts`, import `BookFormatEnum`, `BookLanguageEnum` from `~/domain/book/infrastructure/graphql/enums`, `DetectedBookType` from `./types`, and `ShelfOutcome` from the use case. Append:

```ts
const DetectedBookInput = builder.inputType('DetectedBookInput', {
  description:
    'A book ticked on the shelf checklist, as the reader left it: what `detectBooks` ' +
    'read, with any title or author they corrected.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', required: true }),
    authors: t.field({ type: ['AuthorName'], required: true }),
    publisher: t.field({ type: 'Publisher' }),
    language: t.field({ type: BookLanguageEnum }),
    format: t.field({ type: BookFormatEnum }),
  }),
})

const shelfAnswered = (outcome: ShelfOutcome) =>
  match(outcome)
    .with('premium-required', () =>
      domainError('PREMIUM_REQUIRED', 'Importing a shelf is a Premium feature'),
    )
    .with('quota-exhausted', () => domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up'))
    .with({ failed: P.string }, ({ failed }) => domainError('SCAN_FAILED', failed))
    .with(P.array(), (books) => books)
    .exhaustive()

builder.mutationField('detectBooks', (t) =>
  t.field({
    type: [DetectedBookType],
    description:
      'Find every book in one photo — spines on a shelf, or covers laid out flat — ' +
      'and where each sits, for the reader to tick the ones to add.\n\n' +
      'One model call without web search: only what is printed is read, and a spine ' +
      'that cannot be read comes back with no title rather than a guess. At most 30 ' +
      'books, left to right and top to bottom. Books the reader already owns are ' +
      'flagged `owned`.\n\n' +
      'Premium only: fails with `PREMIUM_REQUIRED` for a free account. Spends nothing ' +
      '— each book kept costs its own `describeDetectedBook` — but fails with ' +
      '`QUOTA_EXHAUSTED` once the allowance is used up, `IMAGE_TOO_LARGE` above the ' +
      '10 MB limit, or `SCAN_FAILED` when the model call errors.',
    args: {
      imageBase64: t.arg.string({
        required: true,
        description: 'The photo as a base64-encoded JPEG (no data URL prefix), up to 10 MB',
      }),
    },
    resolve: async (_root, { imageBase64 }, { userId, event }) => {
      if (!imageWithinSizeLimit(imageBase64.length))
        return domainError('IMAGE_TOO_LARGE', 'Image exceeds the 10 MB size limit')
      return shelfAnswered(
        await ScanUseCase.detectBooks(
          userId,
          Buffer.from(imageBase64, 'base64'),
          languageFrom(event && getHeader(event, 'accept-language')),
        ),
      )
    },
  }),
)

builder.mutationField('describeDetectedBook', (t) =>
  t.field({
    type: ScanResultType,
    description:
      'Build the record of a book ticked on the shelf checklist, as `scanBook` does ' +
      'once a cover is read: web-grounded enrichment, published cover, and the saga ' +
      'and author catalogues when nobody built them yet. Nothing is saved; `addBook` ' +
      'persists it.\n\n' +
      'Never cached, and spends one scan of the allowance once the model answered. ' +
      'Fails with `QUOTA_EXHAUSTED` once nothing is left, or `SCAN_FAILED` when the ' +
      'model call errors.',
    args: { book: t.arg({ type: DetectedBookInput, required: true }) },
    resolve: async (_root, { book }, { userId, event }) =>
      answered(
        await ScanUseCase.describeDetected(
          userId,
          {
            recognized: true,
            title: book.title,
            authors: book.authors,
            publisher: book.publisher ?? undefined,
            language: book.language ?? undefined,
            format: book.format ?? undefined,
            subgenres: [],
          },
          languageFrom(event && getHeader(event, 'accept-language')),
        ),
      ),
  }),
)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd server && bun test domain/scan/infrastructure/graphql/mutations.feat.test.ts`
Expected: PASS.

- [ ] **Step 6: Regenerate the schema and check compatibility**

```bash
cd server && bun run generate:graphql && bun run schema:check
```
Expected: `shared/schema.graphql` gains the two mutations, two types and one input; `schema:check` reports no breaking change (additions only).

- [ ] **Step 7: Full server gate and commit**

```bash
cd server && bunx nitro prepare && bunx tsc --noEmit && bunx biome check
bun test domain/scan/business-rules.unit.test.ts && bun test domain/scan/use-case.int.test.ts && bun test domain/scan/infrastructure/graphql/mutations.feat.test.ts
git add server/domain/scan shared/schema.graphql
git commit -m "feat(scan): detectBooks and describeDetectedBook in the GraphQL API"
```

---

### Task 5: iOS API layer

**Files:**
- Create: `ios/Shiori/Features/Scan/GraphQL/Shelf.graphql`
- Create: `ios/Shiori/Features/Scan/ShelfAPI.swift`
- Modify: generated Apollo files (`cd ios && apollo-ios-cli generate`)

**Interfaces:**
- Consumes: the schema of Task 4, `ScannedBook(fields:)`, `LibraryAPI.graphQLFormat`, `LibraryAPI.graphQLLanguage`, `GraphQLHelpers`
- Produces:
  - `struct DetectedBook: Identifiable, Hashable { let id: Int; var title: String?; var authors: [String]; let publisher: String?; let language: BookLanguage?; let format: BookFormat?; let seriesName: String?; let volume: Int?; let box: CGRect; let owned: Bool; var byline: String?; var seriesLabel: String? }`
  - `ShelfAPI.detect(jpeg: Data) async throws -> [DetectedBook]`
  - `ShelfAPI.describe(_ book: DetectedBook) async throws -> ScannedBook`
  - `UIImage.crop(to box: CGRect) -> UIImage?` (normalized box)

- [ ] **Step 1: Write the operations**

Create `ios/Shiori/Features/Scan/GraphQL/Shelf.graphql`:

```graphql
# Every book in one shelf photo, with where it sits. Premium only; spends
# nothing — each book kept is its own DescribeDetectedBook.
mutation DetectBooks($imageBase64: String!) {
  detectBooks(imageBase64: $imageBase64) {
    title
    authors
    publisher
    language
    format
    seriesName
    volume
    owned
    box {
      x
      y
      width
      height
    }
  }
}

# The record of one ticked book, as a scanned cover's. Spends one scan.
mutation DescribeDetectedBook($book: DetectedBookInput!) {
  describeDetectedBook(book: $book) {
    ...ScannedRecord
  }
}
```

- [ ] **Step 2: Generate**

Run: `cd ios && apollo-ios-cli generate`
Expected: new `DetectBooksMutation`, `DescribeDetectedBookMutation` and `DetectedBookInput` under the generated sources.

- [ ] **Step 3: Write the API and model**

Create `ios/Shiori/Features/Scan/ShelfAPI.swift`:

```swift
import Foundation
import UIKit

/// One book found in a shelf photo, as printed — nothing looked up yet. The
/// title and authors are the reader's to correct on the checklist.
struct DetectedBook: Identifiable, Hashable {
    /// Its place in reading order: stable for the life of the checklist.
    let id: Int
    var title: String?
    var authors: [String]
    let publisher: String?
    let language: BookLanguage?
    let format: BookFormat?
    let seriesName: String?
    let volume: Int?
    /// Where it sits, as fractions of the photo that was sent.
    let box: CGRect
    /// The reader already has this story: it comes unticked.
    let owned: Bool

    var byline: String? {
        authors.isEmpty ? nil : authors.joined(separator: ", ")
    }

    var seriesLabel: String? {
        seriesName.map { name in volume.map { "\(name) · Tome \($0)" } ?? name }
    }
}

enum ShelfAPI {
    /// A shelf photo is read in one call without web search, but a large
    /// photo still takes a while: the same ceiling as a scan.
    private static let requestTimeout: TimeInterval = 190

    /// Throws `APIError.domain(code: "PREMIUM_REQUIRED")` for a free account
    /// and `"QUOTA_EXHAUSTED"` once nothing is left.
    static func detect(jpeg: Data) async throws -> [DetectedBook] {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DetectBooksMutation(imageBase64: jpeg.base64EncodedString()),
            requestTimeout: requestTimeout,
            // A proposal: nothing reaches the library before `addBook`.
            changesLibrary: false
        )
        return data.detectBooks.enumerated().map { index, book in
            DetectedBook(
                id: index,
                title: book.title,
                authors: book.authors,
                publisher: book.publisher,
                language: book.language?.asDomain,
                format: book.format?.asDomain,
                seriesName: book.seriesName,
                volume: book.volume,
                box: CGRect(x: book.box.x, y: book.box.y, width: book.box.width, height: book.box.height),
                owned: book.owned
            )
        }
    }

    /// Spends one scan. The answer is saved with `BookAPI.add`, as a scan's is.
    static func describe(_ book: DetectedBook) async throws -> ScannedBook {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DescribeDetectedBookMutation(
                book: ShioriGraphQL.DetectedBookInput(
                    authors: book.authors,
                    format: GraphQLHelpers.graphQLNullable(book.format.map(LibraryAPI.graphQLFormat)),
                    language: GraphQLHelpers.graphQLNullable(book.language.map(LibraryAPI.graphQLLanguage)),
                    publisher: GraphQLHelpers.graphQLNullable(book.publisher),
                    title: book.title ?? ""
                )
            ),
            requestTimeout: requestTimeout,
            changesLibrary: false
        )
        return ScannedBook(fields: data.describeDetectedBook.fragments.scannedRecord)
    }
}

extension UIImage {
    /// The part of the photo inside a box given as fractions of it. Drawn
    /// through a renderer so the photo's orientation is applied first — the
    /// box was measured on the upright image the server saw.
    func crop(to box: CGRect) -> UIImage? {
        let rect = CGRect(
            x: box.minX * size.width,
            y: box.minY * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        ).integral
        guard rect.width > 0, rect.height > 0 else { return nil }
        return UIGraphicsImageRenderer(size: rect.size).image { _ in
            draw(at: CGPoint(x: -rect.minX, y: -rect.minY))
        }
    }
}
```

If the generated initializer orders or types its arguments differently (Apollo sorts them alphabetically and wraps enums in `GraphQLEnum`), follow the generated signature — the `NewBookInput` call in `Features/Book/BookAPI.swift:177` is the model to copy.

- [ ] **Step 4: Build**

Run: `cd ios && xcodebuild -project Shiori.xcodeproj -scheme Shiori -destination 'generic/platform=iOS Simulator' build -quiet`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ios/Shiori/Features/Scan/GraphQL/Shelf.graphql ios/Shiori/Features/Scan/ShelfAPI.swift ios/Shiori/Generated
git commit -m "feat(ios): the shelf detection and description calls"
```

(Adjust the generated path to where `apollo-codegen-config.json` writes; `git status` shows it.)

---

### Task 6: Shelf import view model and camera size

**Files:**
- Modify: `ios/Shiori/Features/Scan/components/organisms/CameraView.swift` (a `maxDimension` parameter)
- Create: `ios/Shiori/Features/Scan/ShelfImportViewModel.swift`
- Modify: `ios/Shiori/Shared/Analytics.swift` (`BookSource.shelf`, `shelfDetected(books:)`)

**Interfaces:**
- Consumes: `ShelfAPI.detect`, `ShelfAPI.describe`, `BookAPI.add`, `SubscriptionAPI.quota()`, `UIImage.crop(to:)`
- Produces:
  - `CameraView(maxDimension: CGFloat = 800, onCapture:shouldCapture:)`
  - `ShelfImportViewModel` with `step: Step` (`.camera`, `.detecting`, `.checklist`, `.noResult`, `.failed`, `.adding`), `photo: UIImage?`, `books: [DetectedBook]`, `ticked: Set<Int>`, `progress: [Int: Progress]`, `remainingScans: Int?`, `paywallShown`, `failure`, and `detect(_ jpeg: Data) async`, `retry() async`, `retake()`, `toggle(_ id: Int)`, `correct(_ id: Int, title: String, authors: [String])`, `crop(of: DetectedBook) -> UIImage?`, `addTicked()`, `retryAdding(_ id: Int)`
  - `enum Progress { case waiting, adding, added, failed(String) }`

- [ ] **Step 1: Let the camera keep a larger photo**

In `CameraView.swift`, add `var maxDimension: CGFloat = 800` to `CameraView` (first stored property, so existing call sites are unchanged), pass it in `makeUIViewController` as `controller.maxDimension = maxDimension`, add `var maxDimension: CGFloat = 800` to `CameraViewController`, and hand it to the delegate: in `viewDidLoad` set `delegateHandler.maxDimension = maxDimension`. In `PhotoCaptureDelegate` add `var maxDimension: CGFloat = 800` and replace `resized(maxDimension: 800).jpegData(compressionQuality: 0.6)` with:

```swift
image.resized(maxDimension: maxDimension).jpegData(compressionQuality: maxDimension > 800 ? 0.7 : 0.6)
```

- [ ] **Step 2: Analytics**

In `Shared/Analytics.swift`: add `case shelfDetected(books: Int)` after `scanBlockedByQuota`; add to `BookSource`:

```swift
        /// Ticked on a shelf photo: a scan, counted apart to see what the
        /// batch import is worth against one cover at a time.
        case shelf
```

In `name`, `case .shelfDetected: "shelf_detected"`; in `parameters`, `case let .shelfDetected(books): ["books": books]`.

- [ ] **Step 3: Write the view model**

Create `ios/Shiori/Features/Scan/ShelfImportViewModel.swift`:

```swift
import SwiftUI

/// Drives one shelf photo: capture, detection, the checklist, then adding the
/// ticked books three at a time.
///
/// Adding is owned here rather than by a view, so closing the sheet does not
/// cancel it: the books keep landing in the library while the app lives. A
/// book not yet saved when the app is killed is simply not there; importing
/// the photo again shows the saved ones as already owned.
@MainActor
@Observable
final class ShelfImportViewModel {
    enum Step: Equatable {
        case camera
        case detecting
        case checklist
        case noResult
        case failed
        case adding
    }

    enum Progress: Equatable {
        case waiting
        case adding
        case added
        case failed(String)
    }

    /// The photo is sent at this size: a spine's title is a few pixels tall,
    /// where a cover's reads fine at 1000.
    static let photoDimension: CGFloat = 2000
    private static let parallelAdds = 3

    private(set) var step: Step = .camera
    /// The very image the server saw, so the boxes crop what it read.
    private(set) var photo: UIImage?
    private var jpeg: Data?
    private(set) var books: [DetectedBook] = []
    private(set) var ticked: Set<Int> = []
    private(set) var progress: [Int: Progress] = [:]
    /// What is left of the allowance, month and granted scans together. Nil
    /// until read, or when it could not be.
    private(set) var remainingScans: Int?
    private(set) var failure: String?
    var paywallShown = false
    private var crops: [Int: UIImage] = [:]

    var tickedCount: Int { ticked.count }

    var isDone: Bool {
        !progress.isEmpty && progress.values.allSatisfy { $0 == .added }
    }

    func detect(_ jpeg: Data) async {
        self.jpeg = jpeg
        photo = UIImage(data: jpeg)
        crops = [:]
        failure = nil
        step = .detecting
        do {
            async let found = ShelfAPI.detect(jpeg: jpeg)
            async let quota = try? SubscriptionAPI.quota()
            books = try await found
            if let quota = await quota { remainingScans = quota.totalRemaining }
            track(.shelfDetected(books: books.count))
            ticked = Set(books.filter { !$0.owned && $0.title?.isEmpty == false }.map(\.id))
            step = books.isEmpty ? .noResult : .checklist
        } catch let APIError.domain(code, _) where code == "PREMIUM_REQUIRED" || code == "QUOTA_EXHAUSTED" {
            step = .camera
            paywallShown = true
        } catch {
            failure = reportError(error)
            step = .failed
        }
    }

    func retry() async {
        guard let jpeg else { return retake() }
        await detect(jpeg)
    }

    func retake() {
        jpeg = nil
        photo = nil
        books = []
        ticked = []
        progress = [:]
        crops = [:]
        failure = nil
        step = .camera
    }

    /// An unreadable book cannot be ticked until the reader names it.
    func toggle(_ id: Int) {
        guard let book = books.first(where: { $0.id == id }), book.title?.isEmpty == false else { return }
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
    }

    /// The reader's reading of the spine replaces the model's, and ticks it.
    func correct(_ id: Int, title: String, authors: [String]) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        books[index].title = trimmed
        books[index].authors = authors
        ticked.insert(id)
    }

    func crop(of book: DetectedBook) -> UIImage? {
        if let cached = crops[book.id] { return cached }
        let cropped = photo?.crop(to: book.box)
        crops[book.id] = cropped
        return cropped
    }

    /// More books ticked than scans left: the checklist says how many remain
    /// rather than starting a run that would stop halfway.
    var exceedsAllowance: Bool {
        remainingScans.map { tickedCount > $0 } ?? false
    }

    func addTicked() {
        let chosen = books.filter { ticked.contains($0.id) }
        progress = Dictionary(uniqueKeysWithValues: chosen.map { ($0.id, Progress.waiting) })
        step = .adding
        Task { await add(chosen) }
    }

    func retryAdding(_ id: Int) {
        guard let book = books.first(where: { $0.id == id }) else { return }
        progress[id] = .waiting
        Task { await add([book]) }
    }

    private func add(_ chosen: [DetectedBook]) async {
        await withTaskGroup(of: Void.self) { group in
            var pending = chosen[...]
            for _ in 0 ..< min(Self.parallelAdds, pending.count) {
                let book = pending.removeFirst()
                group.addTask { await self.addOne(book) }
            }
            while await group.next() != nil, let book = pending.popFirst() {
                group.addTask { await self.addOne(book) }
            }
        }
    }

    private func addOne(_ book: DetectedBook) async {
        progress[book.id] = .adding
        do {
            let scanned = try await ShelfAPI.describe(book)
            _ = try await BookAPI.add(scanned.asDraft)
            track(.bookAdded(source: .shelf))
            progress[book.id] = .added
        } catch let APIError.domain(code, _) where code == "QUOTA_EXHAUSTED" {
            progress[book.id] = .failed(String(localized: "Scans épuisés"))
        } catch {
            progress[book.id] = .failed(reportError(error))
        }
    }
}
```

- [ ] **Step 4: Build**

Run: `cd ios && xcodebuild -project Shiori.xcodeproj -scheme Shiori -destination 'generic/platform=iOS Simulator' build -quiet`
Expected: `** BUILD SUCCEEDED **`, no new warnings under strict concurrency.

- [ ] **Step 5: Commit**

```bash
git add ios/Shiori/Features/Scan ios/Shiori/Shared/Analytics.swift
git commit -m "feat(ios): drive a shelf import from photo to library"
```

---

### Task 7: Shelf import screens

**Files:**
- Create: `ios/Shiori/Features/Scan/ShelfImportView.swift`
- Create: `ios/Shiori/Features/Scan/components/pages/ShelfChecklistPage.swift`
- Create: `ios/Shiori/Features/Scan/components/pages/ShelfAddingPage.swift`
- Create: `ios/Shiori/Features/Scan/components/organisms/DetectedBookSheet.swift`
- Create: `ios/Shiori/Features/Scan/components/organisms/ShelfPhoto.swift`

**Interfaces:**
- Consumes: `ShelfImportViewModel` (Task 6), `CameraView(maxDimension:)`, `ScanAnalyzingPage(coverData:)`, `ScanNoResultPage`, `ScanFailedPage`, `PremiumSheet(trigger:)`
- Produces:
  - `ShelfImportView(start: ShelfImportView.Start, onDismiss: () -> Void)` with `enum Start { case camera, photo(Data) }`
  - `PremiumTrigger.shelfImport`

- [ ] **Step 1: The photo with its frames**

Create `components/organisms/ShelfPhoto.swift`:

```swift
import SwiftUI

/// The reader's photo with a frame on every book found. The highlighted one
/// is the row the reader last touched, so a spine and its line are easy to
/// match up.
struct ShelfPhoto: View {
    let photo: UIImage
    let books: [DetectedBook]
    var highlighted: Int?

    var body: some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    ForEach(books) { book in
                        Rectangle()
                            .strokeBorder(book.id == highlighted ? Color.yellow : Color.green, lineWidth: book.id == highlighted ? 3 : 1.5)
                            .frame(width: book.box.width * proxy.size.width, height: book.box.height * proxy.size.height)
                            .position(x: book.box.midX * proxy.size.width, y: book.box.midY * proxy.size.height)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 2: The correction sheet**

Create `components/organisms/DetectedBookSheet.swift`:

```swift
import SwiftUI

/// Name a spine the model could not read, or fix one it misread: the crop
/// enlarged, a title and the authors. The rest is looked up when it is added.
struct DetectedBookSheet: View {
    let book: DetectedBook
    let crop: UIImage?
    let onSave: (String, [String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var authors: String

    init(book: DetectedBook, crop: UIImage?, onSave: @escaping (String, [String]) -> Void) {
        self.book = book
        self.crop = crop
        self.onSave = onSave
        _title = State(initialValue: book.title ?? "")
        _authors = State(initialValue: book.authors.joined(separator: ", "))
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let crop {
                    Section {
                        Image(uiImage: crop)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                    }
                }
                Section("Titre") {
                    TextField("Titre du livre", text: $title)
                        .accessibilityIdentifier("shelf-correct-title")
                }
                Section("Auteurs") {
                    TextField("Séparés par des virgules", text: $authors)
                        .accessibilityIdentifier("shelf-correct-authors")
                }
            }
            .navigationTitle("Corriger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        let names = authors.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        onSave(trimmedTitle, names)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
```

- [ ] **Step 3: The checklist**

Create `components/pages/ShelfChecklistPage.swift`:

```swift
import SwiftUI

/// Every book of the photo, ticked unless the reader owns it already or its
/// title could not be read. The button says what the run will cost.
struct ShelfChecklistPage: View {
    @Bindable var viewModel: ShelfImportViewModel
    @State private var highlighted: Int?
    @State private var correcting: DetectedBook?
    @State private var allowanceAlert = false

    var body: some View {
        List {
            if let photo = viewModel.photo {
                Section {
                    ShelfPhoto(photo: photo, books: viewModel.books, highlighted: highlighted)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                ForEach(viewModel.books) { book in
                    row(book)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { addButton }
        .navigationTitle("\(viewModel.books.count) livres trouvés")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $correcting) { book in
            DetectedBookSheet(book: book, crop: viewModel.crop(of: book)) { title, authors in
                viewModel.correct(book.id, title: title, authors: authors)
            }
        }
        .alert("Pas assez de scans", isPresented: $allowanceAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Il vous reste \(viewModel.remainingScans ?? 0) scans ce mois-ci. Décochez des livres pour continuer.")
        }
    }

    private func row(_ book: DetectedBook) -> some View {
        HStack(spacing: 12) {
            Button { viewModel.toggle(book.id) } label: {
                Image(systemName: viewModel.ticked.contains(book.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(viewModel.ticked.contains(book.id) ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.ticked.contains(book.id) ? "Décocher" : "Cocher")
            .accessibilityIdentifier("shelf-tick-\(book.id)")

            Group {
                if let crop = viewModel.crop(of: book) {
                    Image(uiImage: crop).resizable().scaledToFit()
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 32, height: 48)
            .clipShape(.rect(cornerRadius: 3))

            VStack(alignment: .leading, spacing: 2) {
                if let title = book.title, !title.isEmpty {
                    Text(title).font(.body.weight(.medium)).lineLimit(2)
                    if let line = [book.byline, book.seriesLabel].compactMap(\.self).joined(separator: " · ").nilIfEmpty {
                        Text(line).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    Text("Tranche illisible").font(.body.weight(.medium)).foregroundStyle(.orange)
                    Text("Touchez pour saisir le titre").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if book.owned {
                Text("Déjà chez vous")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15), in: .capsule)
                    .foregroundStyle(.green)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            highlighted = book.id
            correcting = book
        }
        .accessibilityIdentifier("shelf-row-\(book.id)")
    }

    private var addButton: some View {
        Button {
            if viewModel.exceedsAllowance { allowanceAlert = true } else { viewModel.addTicked() }
        } label: {
            Text("Ajouter \(viewModel.tickedCount) livres · \(viewModel.tickedCount) scans")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.tickedCount == 0)
        .padding()
        .background(.bar)
        .accessibilityIdentifier("shelf-add")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
```

Tapping a row opens the correction sheet and highlights its frame; the tick is its own button so a tap meant to tick never opens a sheet.

- [ ] **Step 4: The adding page**

Create `components/pages/ShelfAddingPage.swift`:

```swift
import SwiftUI

/// One line per ticked book as it is described and saved. The sheet can be
/// closed at any point: the work belongs to the view model, not this page.
struct ShelfAddingPage: View {
    let viewModel: ShelfImportViewModel
    let onDone: () -> Void

    private var chosen: [DetectedBook] {
        viewModel.books.filter { viewModel.progress[$0.id] != nil }
    }

    var body: some View {
        List(chosen) { book in
            HStack(spacing: 12) {
                icon(for: viewModel.progress[book.id] ?? .waiting)
                    .frame(width: 24)
                Text(book.title ?? "")
                    .lineLimit(2)
                Spacer(minLength: 0)
                if case .failed = viewModel.progress[book.id] {
                    Button("Réessayer") { viewModel.retryAdding(book.id) }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("shelf-retry-\(book.id)")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !viewModel.isDone {
                    Text("Vous pouvez fermer : l'ajout continue et les livres apparaissent dans la bibliothèque.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button("Voir ma bibliothèque", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("shelf-done")
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Ajout de \(chosen.count) livres")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func icon(for progress: ShelfImportViewModel.Progress) -> some View {
        switch progress {
        case .waiting:
            Image(systemName: "clock").foregroundStyle(.secondary)
        case .adding:
            ProgressView()
        case .added:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case let .failed(reason):
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                .accessibilityLabel(reason)
        }
    }
}
```

- [ ] **Step 5: The flow container**

Create `ios/Shiori/Features/Scan/ShelfImportView.swift`:

```swift
import SwiftUI

/// A shelf in one photo: the camera or a picked photo, the books found, the
/// checklist, then the run that adds them. Beside `ScanView` rather than
/// inside it: one book reviewed field by field and thirty ticked in a list
/// share a camera and nothing else.
struct ShelfImportView: View {
    enum Start {
        case camera
        case photo(Data)
    }

    var start: Start = .camera
    var onDismiss: () -> Void

    @State private var viewModel = ShelfImportViewModel()
    @State private var shouldCapture = false

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel, action: onDismiss)
                    }
                }
        }
        .sheet(isPresented: $viewModel.paywallShown, onDismiss: onDismiss) {
            PremiumSheet(trigger: .shelfImport)
        }
        .task {
            if case let .photo(data) = start { await detect(imageData: data) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .camera:
            cameraScreen
        case .detecting:
            ScanAnalyzingPage(coverData: viewModel.photo?.jpegData(compressionQuality: 0.7))
        case .checklist:
            ShelfChecklistPage(viewModel: viewModel)
        case .noResult:
            ScanNoResultPage(onRetake: viewModel.retake, onDismiss: onDismiss)
        case .failed:
            ScanFailedPage(
                reason: viewModel.failure,
                onRetry: { Task { await viewModel.retry() } },
                onRetake: viewModel.retake
            )
        case .adding:
            ShelfAddingPage(viewModel: viewModel, onDone: onDismiss)
        }
    }

    private var cameraScreen: some View {
        ZStack {
            CameraView(
                maxDimension: ShelfImportViewModel.photoDimension,
                onCapture: { jpeg in Task { await viewModel.detect(jpeg) } },
                shouldCapture: $shouldCapture
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                Text("Tranches bien lisibles, ou couvertures posées à plat. Jusqu'à 30 livres.")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button { shouldCapture = true } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().fill(.white).padding(6))
                }
                .accessibilityLabel(Text("Photographier les livres"))
                .accessibilityIdentifier("shelf-shutter")
                .padding(.bottom, 48)
            }
        }
        .navigationTitle("Plusieurs livres")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func detect(imageData data: Data) async {
        let jpeg = await Task.detached(priority: .userInitiated) {
            UIImage(data: data).flatMap {
                $0.resized(maxDimension: ShelfImportViewModel.photoDimension).jpegData(compressionQuality: 0.7)
            }
        }.value
        guard let jpeg else { return }
        await viewModel.detect(jpeg)
    }
}
```

`ShelfImportViewModel.photoDimension` is `static let` on a `@MainActor` class; if the detached task complains, copy it into a local `let dimension = ShelfImportViewModel.photoDimension` before the `Task.detached`.

- [ ] **Step 6: The paywall trigger**

In `ios/Shiori/Features/Subscription/components/pages/PremiumSheet.swift`, add `case shelfImport` to `PremiumTrigger`, and in its three switches:

```swift
        case .shelfImport: return String(localized: "Plusieurs livres d'un coup")
```
```swift
        case .shelfImport: return "shelf_import"
```
```swift
        case .shelfImport:
            return String(localized: "Photographiez une étagère entière : chaque livre est reconnu, vous cochez ceux à ajouter. Réservé à Shiori Premium.")
```

- [ ] **Step 7: Build**

Run: `cd ios && xcodebuild -project Shiori.xcodeproj -scheme Shiori -destination 'generic/platform=iOS Simulator' build -quiet`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add ios/Shiori/Features/Scan ios/Shiori/Features/Subscription/components/pages/PremiumSheet.swift
git commit -m "feat(ios): the shelf checklist, correction sheet and adding screen"
```

---

### Task 8: Entry point

**Files:**
- Modify: `ios/Shiori/Features/Library/components/organisms/AddBookSheet.swift` (a "Plusieurs livres" tile, `AddBookSource.shelf`)
- Modify: `ios/Shiori/ContentView.swift` (present `ShelfImportView`)

**Interfaces:**
- Consumes: `ShelfImportView(start:onDismiss:)`, `SubscriptionStore.isPremium`
- Produces: `AddBookSource.shelf`, `AddBookSheet(onShelf:)`

- [ ] **Step 1: The tile**

In `AddBookSheet.swift`:
- add `case shelf` to `AddBookSource` with the doc comment `/// A whole shelf in one photo, Premium only.`;
- add `var onShelf: () -> Void = {}` after `onCamera`;
- in `strip`, right after `cameraTile` (inside the same `if hasCamera`), add `shelfTile`;
- add:

```swift
    @Environment(SubscriptionStore.self) private var subscriptions

    /// A shelf in one photo. Shown to everyone, badged for a free reader,
    /// whose tap opens the offer rather than the camera.
    private var shelfTile: some View {
        Button { onShelf() } label: {
            tileBackground {
                VStack(spacing: 6) {
                    Image(systemName: "books.vertical")
                        .font(.title2)
                    Text("Plusieurs livres")
                        .font(.footnote)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                    if subscriptions.isPremium != true {
                        Text("Premium")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15), in: .capsule)
                            .foregroundStyle(.purple)
                    }
                }
                .padding(8)
                .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add-book-shelf")
    }
```

The `#Preview` at the bottom needs `.environment(SubscriptionStore())` if `SubscriptionStore` has a no-argument init; otherwise copy how another preview in `Features/Settings` provides it.

- [ ] **Step 2: Present it**

In `ContentView.swift`:
- add `@State private var shelfStart: ShelfStart?` beside `scanStart`, with

```swift
    /// The shelf import's opening step, boxed so a cover can be keyed on it.
    private struct ShelfStart: Identifiable {
        let id = UUID()
        let start: ShelfImportView.Start
    }
    @State private var shelfPaywall = false
    @Environment(SubscriptionStore.self) private var subscriptions
```

(skip the `@Environment` line if `ContentView` already reads `SubscriptionStore`);
- pass `onShelf: { choose(.shelf) }` to `AddBookSheet`;
- after the scan `.fullScreenCover`, add

```swift
            .fullScreenCover(item: $shelfStart) { boxed in
                ShelfImportView(start: boxed.start, onDismiss: { shelfStart = nil })
            }
            .sheet(isPresented: $shelfPaywall) {
                PremiumSheet(trigger: .shelfImport)
            }
```

- in `actOnPendingSource`, add

```swift
        // Unknown until the store has loaded: the flow opens, and the server's
        // PREMIUM_REQUIRED brings the offer up for a free reader all the same.
        case .shelf:
            if subscriptions.isPremium == false {
                shelfPaywall = true
            } else {
                shelfStart = ShelfStart(start: .camera)
            }
```

- [ ] **Step 3: Build**

Run: `cd ios && xcodebuild -project Shiori.xcodeproj -scheme Shiori -destination 'generic/platform=iOS Simulator' build -quiet`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Screenshot for validation**

The simulator stops at the Apple sign-in wall, so the screens are shown through their SwiftUI previews. Add a `#Preview` to `ShelfChecklistPage.swift` fed with a view model in `.checklist` (expose a `static func preview() -> ShelfImportViewModel` under `#if DEBUG` in the view model that sets `photo`, three `books` — one owned, one without title — `ticked` and `step`), render it, screenshot the checklist, the adding page and the add sheet tile, and send them to the user. **Wait for their approval before the next task or any iPhone install.**

- [ ] **Step 5: Commit**

```bash
git add ios/Shiori/Features/Library/components/organisms/AddBookSheet.swift ios/Shiori/ContentView.swift ios/Shiori/Features/Scan
git commit -m "feat(ios): open a shelf import from the add sheet"
```

---

### Task 9: Real-photo calibration

**Files:** none committed unless the prompt or model changes.

- [ ] **Step 1: Collect four photos**

With the user: a shelf of spines (15–25 books), covers laid out on a floor (6–10), mixed formats (manga and novels), and a partly unreadable shelf (glare, thin spines).

- [ ] **Step 2: Run detection against Gemini**

With `NITRO_SCAN_STUB` unset, a Premium `NITRO_DEV_USER_ID` (listed in `premiumUserIds`), and `bun run dev`, send each photo (resized to 2000 px, JPEG 0.7) to `detectBooks` from Apollo Sandbox. For each, note: books present, books found, titles correct, false titles (a guess where the spine is unreadable), boxes that miss their book.

- [ ] **Step 3: Decide**

A false title is worse than a missing one. If Flash-Lite invents titles or misses more than one book in five, try `gemini-3.6-flash` for the `shelf` step only (a `model` option on `generate`, and its rates in `server/domain/admin/business-rules.ts`), and report both results to the user before changing anything.

---

## Self-review

- Spec coverage: entry and paywall (T8), viewfinder hint and 2000 px (T6, T7), detection frames (T7 `ShelfPhoto`), checklist with owned/unreadable/crop/highlight (T7), allowance message (T6 `exceedsAllowance`, T7 alert), correction sheet (T7), adding 3 at a time with retry and closable sheet (T6, T7), `detectBooks` premium/quota/30/no cache/usage/size (T2, T4), `describeDetectedBook` with catalogues and one scan (T3, T4), tests at three suffixes (T1–T4), real-photo calibration (T9).
- Names checked across tasks: `SeenOnShelf`, `DetectedBook`, `ShelfOutcome`, `ScanCommand.detectBooks`, `ScanCommand.describeDetected`, `ScanUseCase.detectBooks`, `ScanUseCase.describeDetected`, `AdminCommand.recordShelfUsage`, `ShelfAPI.detect/describe`, `ShelfImportViewModel.photoDimension`, `PremiumTrigger.shelfImport`, `AddBookSource.shelf`.
