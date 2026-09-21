import { describe, expect, test } from 'bun:test'
import type { AudibleGenre, AudibleItem, CategoryLadder } from 'audible-api-ts'
import { resolveGenreId } from 'audible-api-ts'
import { genreFrom, subgenresFrom } from '~/domain/audible/genre-mapping'

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

describe('a title on several ladders', () => {
  // Amazon lists the catch-all literary rack first for half its catalogue, and
  // taking the first ladder filed Le problème à trois corps as literary fiction.
  test('lets a specific rack outvote a generic one listed before it', () => {
    const item = shelvedIn(
      ladderOf(['literary-fiction']),
      ladderOf(['science-fiction-fantasy', 'science-fiction', 'science-fiction/military']),
    )

    expect(genreFrom(item)).toBe('science-fiction')
  })

  test('gives the genre most ladders name', () => {
    const item = shelvedIn(
      ladderOf(['thriller']),
      ladderOf(['science-fiction-fantasy', 'fantasy', 'fantasy/epic']),
      ladderOf(['science-fiction-fantasy', 'fantasy', 'fantasy/dragons']),
    )

    expect(genreFrom(item)).toBe('fantasy')
  })

  // Dune sits on a science-fiction ladder and an epic fantasy one, science
  // fiction first.
  test('breaks a tie in favour of the earlier ladder', () => {
    const item = shelvedIn(
      ladderOf(['science-fiction-fantasy', 'science-fiction']),
      ladderOf(['science-fiction-fantasy', 'fantasy', 'fantasy/epic']),
    )

    expect(genreFrom(item)).toBe('science-fiction')
  })

  test('still answers from a generic rack when it is all there is', () => {
    expect(genreFrom(shelvedIn(ladderOf(['literary-fiction', 'literary-fiction/classics'])))).toBe(
      'literary-fiction',
    )
  })
})

describe('a shelf that is not a genre', () => {
  // `GENRES` says so outright: an audience is not a genre. But "Jeunesse" is
  // exactly what a subgenre is for — the scan names it as one of its own
  // examples — so the shelf is kept there rather than dropped.
  test('records an audience as a subgenre instead', () => {
    expect(genreFrom(shelvedIn(ladderOf(['children'])))).toBeUndefined()
    expect(subgenresFrom(shelvedIn(ladderOf(['children']))).map(String)).toEqual(['Jeunesse'])
  })

  test('records a theme as a subgenre instead', () => {
    expect(genreFrom(shelvedIn(ladderOf(['lgbtq'])))).toBeUndefined()
    expect(subgenresFrom(shelvedIn(ladderOf(['lgbtq']))).map(String)).toEqual(['LGBTQ+'])
    expect(subgenresFrom(shelvedIn(ladderOf(['sports']))).map(String)).toEqual(['Sport'])
  })

  // The two answer different questions, so the subgenre is kept even when a rung
  // below the audience supplied the genre.
  test('keeps both when the rung below the audience names the genre', () => {
    const item = shelvedIn(ladderOf(['young-adult', 'young-adult/thriller']))

    expect(genreFrom(item)).toBe('thriller')
    expect(subgenresFrom(item).map(String)).toEqual(['Young adult'])
  })

  test('says nothing extra for a title whose every shelf is a genre', () => {
    expect(subgenresFrom(shelvedIn(ladderOf(['fantasy', 'fantasy/epic'])))).toEqual([])
  })

  // A title sits on several ladders and they overlap, so the same audience comes
  // back twice.
  test('records a shelf once however many ladders name it', () => {
    const item = shelvedIn(
      ladderOf(['children']),
      ladderOf(['children', 'children/action-adventure']),
    )

    expect(subgenresFrom(item).map(String)).toEqual(['Jeunesse'])
  })

  test('keeps at most three, the first being the one the library list shows', () => {
    const item = shelvedIn(
      ladderOf(['children']),
      ladderOf(['young-adult']),
      ladderOf(['lgbtq']),
      ladderOf(['sports']),
    )

    expect(subgenresFrom(item).map(String)).toEqual(['Jeunesse', 'Young adult', 'LGBTQ+'])
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
    expect(subgenresFrom(shelvedIn(shelfOnSomeOtherStore))).toEqual([])
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
