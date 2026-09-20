import { describe, expect, test } from 'bun:test'
import type { AudibleGenre, AudibleItem, CategoryLadder } from 'audible-api-ts'
import { resolveGenreId } from 'audible-api-ts'
import { genreFrom } from '~/domain/audible/genre-mapping'

/** A ladder built from the shelves Audible would file a title under, root first.
 *
 *  The ids come from `resolveGenreId` rather than being typed out: they are
 *  eleven-digit numbers, and a test that restates them would only assert that
 *  somebody copied them twice. What is worth asserting is which shelf wins and
 *  what Shiori calls it. */
const ladderOf = (
  shelves: readonly AudibleGenre[],
  locale: 'fr' | 'com' = 'fr',
): CategoryLadder => ({
  root: 'Genres',
  categories: shelves.map((shelf) => ({ id: resolveGenreId(shelf, locale), name: shelf })),
})

const shelvedIn = (...ladders: CategoryLadder[]): AudibleItem =>
  ({ asin: 'B002V1OF70', title: 'Le Nom du vent', categories: ladders }) as AudibleItem

describe('reading the shelf an Audible title sits on', () => {
  test('reads the ladder leaf first, so the rung below a joint rack decides', () => {
    const item = shelvedIn(ladderOf(['science-fiction-fantasy', 'fantasy', 'fantasy/epic']))

    expect(genreFrom(item)).toBe('fantasy')
  })

  // The joint rack is genuinely ambiguous, so it only ever answers when nothing
  // more precise is on the ladder.
  test('falls back on the joint rack when no rung below it says more', () => {
    expect(genreFrom(shelvedIn(ladderOf(['science-fiction-fantasy'])))).toBe('science-fiction')
  })

  test('says it in Shiori words rather than in Audible words', () => {
    expect(genreFrom(shelvedIn(ladderOf(['mystery'])))).toBe('crime')
    expect(genreFrom(shelvedIn(ladderOf(['comedy'])))).toBe('humor')
    expect(genreFrom(shelvedIn(ladderOf(['erotica'])))).toBe('romance')
    expect(genreFrom(shelvedIn(ladderOf(['religion'])))).toBe('essay')
  })

  // Audible's shelf is the rack the reader bought from, and it is how they will
  // look for the book again — whatever the story is actually about.
  test('keeps a fantasy romance on the romance shelf', () => {
    expect(genreFrom(shelvedIn(ladderOf(['romance', 'romance/fantasy'])))).toBe('romance')
  })

  test('lets a literary rung overrule its own rack', () => {
    expect(genreFrom(shelvedIn(ladderOf(['literary-fiction', 'literary-fiction/drama'])))).toBe(
      'drama',
    )
    expect(
      genreFrom(shelvedIn(ladderOf(['literary-fiction', 'literary-fiction/sea-adventures']))),
    ).toBe('adventure')
  })
})

describe('what is not a genre', () => {
  // `GENRES` says so outright: an audience is not a genre, and neither is the
  // object. A young-adult shelf must not become one.
  test('refuses an audience', () => {
    expect(genreFrom(shelvedIn(ladderOf(['children'])))).toBeUndefined()
    expect(genreFrom(shelvedIn(ladderOf(['young-adult'])))).toBeUndefined()
  })

  test('still reads the genre under an audience', () => {
    expect(genreFrom(shelvedIn(ladderOf(['young-adult', 'young-adult/thriller'])))).toBe('thriller')
  })

  // Left empty rather than swept into `other`, which has to stay something the
  // reader chose for themselves.
  test('refuses a theme', () => {
    expect(genreFrom(shelvedIn(ladderOf(['lgbtq'])))).toBeUndefined()
    expect(genreFrom(shelvedIn(ladderOf(['sports'])))).toBeUndefined()
  })
})

describe('across marketplaces', () => {
  test('answers the same for a shelf whose id differs per store', () => {
    expect(genreFrom(shelvedIn(ladderOf(['thriller'], 'fr')))).toBe('thriller')
    expect(genreFrom(shelvedIn(ladderOf(['thriller'], 'com')))).toBe('thriller')
  })

  // The honest limit of matching on ids: the package knows them for `fr` and
  // `com`, so a German library imports without a genre and the reader picks one
  // on the book screen — exactly what a book typed in by hand does.
  test('says nothing for a store whose ids are unknown', () => {
    const shelfOnSomeOtherStore: CategoryLadder = {
      root: 'Genres',
      categories: [{ id: '19276890031', name: 'Fantasy' }],
    }

    expect(genreFrom(shelvedIn(shelfOnSomeOtherStore))).toBeUndefined()
  })
})

describe('a title with nothing to read', () => {
  test('says nothing when there is no ladder at all', () => {
    expect(genreFrom(shelvedIn())).toBeUndefined()
  })

  test('takes the first shelf it recognizes when a title sits on several', () => {
    const item = shelvedIn(ladderOf(['sports']), ladderOf(['biography']))

    expect(genreFrom(item)).toBe('biography')
  })
})
