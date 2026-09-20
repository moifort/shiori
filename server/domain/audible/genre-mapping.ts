import type { AudibleGenre, AudibleItem } from 'audible-api-ts'
import { GENRE_CATEGORIES } from 'audible-api-ts'
import { MAX_SUBGENRES, Subgenre } from '~/domain/book/primitives'
import type { Genre, Subgenre as SubgenreValue } from '~/domain/book/types'

/** What one Audible shelf says about a book: the genre it belongs to, or — when
 *  the shelf is not a genre at all — the subgenre that records it anyway.
 *
 *  Every shelf says one or the other. There is no third case and no `undefined`:
 *  a shelf nobody decided about would go missing in silence, and the union is
 *  what forces the decision to be written down. */
type Shelf = { genre: Genre } | { subgenre: string }

/** What each of Audible's shelves becomes here.
 *
 *  Exhaustive by type on purpose: `audible-api-ts` adding a shelf breaks this
 *  build rather than silently importing a decade of listening with nothing said
 *  about it.
 *
 *  Four decisions worth reading before changing one:
 *
 *  - **An audience is not a genre.** `children` and `young-adult` say who a book
 *    is for, which `GENRES` refuses to record. They become subgenres instead, so
 *    nothing is lost — and the rungs below them still supply the genre: a
 *    young-adult thriller is a thriller filed under "Young adult".
 *  - **A theme is not a genre either.** `lgbtq` and `sports` describe what a book
 *    is about across every rack, so they land in subgenres rather than being
 *    swept into `other`, which has to stay something the reader chose.
 *  - **Audible's shelf wins over the subject.** `romance/fantasy` is romance and
 *    `romance/science-fiction` is romance: that is the rack the reader bought
 *    from, and it is how they will look for it again.
 *  - **`science-fiction-fantasy` is genuinely ambiguous.** It is a joint rack, so
 *    it only answers when no rung below it does — and then it answers
 *    `science-fiction`, the broader of the two.
 *
 *  The subgenre labels are written here rather than taken from Audible's own
 *  shelf name, for the same reason the ids are matched and the names are not: the
 *  name arrives translated per marketplace and reworded between seasons, and a
 *  library would end up carrying "Jeunesse" and "Children's" as two different
 *  subgenres. They are French because that is what a subgenre is here — the scan
 *  writes them in French, and "jeunesse" is one of its own examples. */
const SHELF: Record<AudibleGenre, Shelf> = {
  'science-fiction': { genre: 'science-fiction' },
  fantasy: { genre: 'fantasy' },
  'science-fiction-fantasy': { genre: 'science-fiction' },
  thriller: { genre: 'thriller' },
  mystery: { genre: 'crime' },
  horror: { genre: 'horror' },
  romance: { genre: 'romance' },
  'historical-fiction': { genre: 'historical-fiction' },
  'literary-fiction': { genre: 'literary-fiction' },
  biography: { genre: 'biography' },
  history: { genre: 'history' },
  business: { genre: 'business' },
  'self-help': { genre: 'self-help' },
  science: { genre: 'science' },
  children: { subgenre: 'Jeunesse' },
  'young-adult': { subgenre: 'Young adult' },
  comedy: { genre: 'humor' },
  erotica: { genre: 'romance' },
  religion: { genre: 'essay' },
  sports: { subgenre: 'Sport' },
  travel: { genre: 'travel' },
  lgbtq: { subgenre: 'LGBTQ+' },

  'science-fiction/adventure': { genre: 'science-fiction' },
  'science-fiction/adaptations': { genre: 'science-fiction' },
  'science-fiction/cyberpunk': { genre: 'science-fiction' },
  'science-fiction/dystopian': { genre: 'science-fiction' },
  'science-fiction/first-contact': { genre: 'science-fiction' },
  'science-fiction/galactic-empire': { genre: 'science-fiction' },
  'science-fiction/genetic-engineering': { genre: 'science-fiction' },
  'science-fiction/military': { genre: 'science-fiction' },
  'science-fiction/post-apocalyptic': { genre: 'science-fiction' },
  'science-fiction/space-exploration': { genre: 'science-fiction' },
  'science-fiction/space-opera': { genre: 'science-fiction' },

  'fantasy/action-adventure': { genre: 'fantasy' },
  'fantasy/adaptations': { genre: 'fantasy' },
  'fantasy/dragons': { genre: 'fantasy' },
  'fantasy/epic': { genre: 'fantasy' },
  'fantasy/historical': { genre: 'fantasy' },
  'fantasy/urban-paranormal': { genre: 'fantasy' },

  'thriller/suspense': { genre: 'thriller' },
  'thriller/psychological': { genre: 'thriller' },
  'thriller/domestic': { genre: 'thriller' },
  'thriller/historical': { genre: 'thriller' },

  'mystery/amateur-sleuth': { genre: 'crime' },
  'mystery/detective': { genre: 'crime' },
  'mystery/historical': { genre: 'crime' },
  'mystery/noir': { genre: 'crime' },
  'mystery/private-investigator': { genre: 'crime' },
  'mystery/traditional': { genre: 'crime' },

  'romance/action-adventure': { genre: 'romance' },
  'romance/comedy': { genre: 'romance' },
  'romance/contemporary': { genre: 'romance' },
  'romance/fantasy': { genre: 'romance' },
  'romance/historical': { genre: 'romance' },
  'romance/paranormal': { genre: 'romance' },
  'romance/science-fiction': { genre: 'romance' },
  'romance/sports': { genre: 'romance' },
  'romance/suspense': { genre: 'romance' },

  // Literary fiction is the one rack whose rungs genuinely change the shelf: a
  // sea adventure is an adventure and a play is a drama, whatever aisle Audible
  // files them under.
  'literary-fiction/action-adventure': { genre: 'adventure' },
  'literary-fiction/classics': { genre: 'literary-fiction' },
  'literary-fiction/coming-of-age': { genre: 'literary-fiction' },
  'literary-fiction/contemporary': { genre: 'literary-fiction' },
  'literary-fiction/drama': { genre: 'drama' },
  'literary-fiction/family-life': { genre: 'literary-fiction' },
  'literary-fiction/historical': { genre: 'historical-fiction' },
  'literary-fiction/sagas': { genre: 'literary-fiction' },
  'literary-fiction/sea-adventures': { genre: 'adventure' },
  'literary-fiction/world-literature': { genre: 'literary-fiction' },

  'biography/entertainment': { genre: 'biography' },
  'history/europe': { genre: 'history' },

  'children/action-adventure': { genre: 'adventure' },
  'young-adult/literary-fiction': { genre: 'literary-fiction' },
  'young-adult/romance': { genre: 'romance' },
  'young-adult/science-fiction-fantasy': { genre: 'science-fiction' },
  'young-adult/thriller': { genre: 'thriller' },
}

/** Audible category id to what that shelf says, for every marketplace
 *  `audible-api-ts` knows the ids of — `audible.fr` and `audible.com` today.
 *
 *  Derived rather than typed out: the ids are eleven-digit numbers that mean
 *  nothing to read, one per shelf per marketplace, and the package already keeps
 *  them. A locale it learns next, Shiori gets for free.
 *
 *  Matching on the id and not on the name is the whole point. Audible's shelf
 *  names are translated per marketplace and reworded between seasons, so a table
 *  of names would need ten translations of the genre list and would still drift
 *  out from under us. An id is the same string tomorrow. */
const SHELF_BY_CATEGORY_ID: ReadonlyMap<string, Shelf> = new Map(
  Object.entries(GENRE_CATEGORIES).flatMap(([shelf, idByLocale]) =>
    Object.values(idByLocale).map((id) => [id, SHELF[shelf as AudibleGenre]] as const),
  ),
)

/** Every shelf of a title we recognize, leaf first within each of Audible's
 *  category ladders.
 *
 *  Leaf first is what lets the rung below a joint rack decide: "Science-Fiction
 *  et Fantasy > Fantasy > Épique" has to answer fantasy, and only the rungs below
 *  the joint rack can say so. Ladders come in the order Amazon returns them, the
 *  first being the title's own aisle.
 *
 *  Empty for every marketplace outside `fr` and `com`, whose ids are unknown. */
const shelvesOf = (item: AudibleItem): Shelf[] => {
  const found: Shelf[] = []
  for (const ladder of item.categories ?? []) {
    for (let rung = ladder.categories.length - 1; rung >= 0; rung -= 1) {
      const shelf = SHELF_BY_CATEGORY_ID.get(ladder.categories[rung].id)
      if (shelf) found.push(shelf)
    }
  }
  return found
}

/** The genre an Audible title lands in, or nothing.
 *
 *  Nothing when no shelf is recognized, and nothing when every shelf it sits on
 *  is an audience or a theme. The book is then catalogued without a genre and the
 *  reader picks one on the book screen, which is what a book typed in by hand
 *  does too — but `subgenresFrom` has still kept what those shelves said. */
export const genreFrom = (item: AudibleItem): Genre | undefined => {
  for (const shelf of shelvesOf(item)) {
    if ('genre' in shelf) return shelf.genre
  }
  return undefined
}

/** What the title's shelves say that no genre can hold.
 *
 *  An audience and a theme are not genres, so they would be dropped outright —
 *  yet "Jeunesse" is exactly the kind of label a subgenre is for, and the scan
 *  names it as one of its own examples. They are kept here instead.
 *
 *  Collected whether or not a genre was found, because the two answer different
 *  questions: a young-adult thriller is a thriller, filed under "Young adult".
 *  Deduplicated — a title sits on several ladders and they overlap — and capped
 *  at `MAX_SUBGENRES`, in the order the ladders gave them, since the first is the
 *  only one the library list shows. */
export const subgenresFrom = (item: AudibleItem): SubgenreValue[] => {
  const labels = shelvesOf(item).flatMap((shelf) => ('subgenre' in shelf ? [shelf.subgenre] : []))
  return [...new Set(labels)].slice(0, MAX_SUBGENRES).map(Subgenre)
}
