import type { AudibleGenre, AudibleItem } from 'audible-api-ts'
import { GENRE_CATEGORIES } from 'audible-api-ts'
import type { Genre } from '~/domain/book/types'

/** Which Shiori genre each Audible shelf stands for, or nothing when the shelf
 *  is not a genre at all.
 *
 *  Exhaustive by type on purpose: `audible-api-ts` adding a shelf breaks this
 *  build rather than silently importing a decade of listening with no genre.
 *
 *  Four decisions worth reading before changing one:
 *
 *  - **An audience is not a genre.** `children` and `young-adult` say who a book
 *    is for, which `GENRES` refuses to record — so they map to nothing and the
 *    rungs below them answer instead: a young-adult thriller is a thriller.
 *  - **A theme is not a genre either.** `lgbtq` belongs in subgenres, and
 *    `sports` has no shelf here; both are left empty rather than swept into
 *    `other`, which has to stay something the reader chose.
 *  - **Audible's shelf wins over the subject.** `romance/fantasy` is romance and
 *    `romance/science-fiction` is romance: that is the rack the reader bought
 *    from, and it is how they will look for it again.
 *  - **`science-fiction-fantasy` is genuinely ambiguous.** It is a joint rack, so
 *    it only answers when no rung below it does — and then it answers
 *    `science-fiction`, the broader of the two. */
const SHIORI_GENRE: Record<AudibleGenre, Genre | undefined> = {
  'science-fiction': 'science-fiction',
  fantasy: 'fantasy',
  'science-fiction-fantasy': 'science-fiction',
  thriller: 'thriller',
  mystery: 'crime',
  horror: 'horror',
  romance: 'romance',
  'historical-fiction': 'historical-fiction',
  'literary-fiction': 'literary-fiction',
  biography: 'biography',
  history: 'history',
  business: 'business',
  'self-help': 'self-help',
  science: 'science',
  children: undefined,
  'young-adult': undefined,
  comedy: 'humor',
  erotica: 'romance',
  religion: 'essay',
  sports: undefined,
  travel: 'travel',
  lgbtq: undefined,

  'science-fiction/adventure': 'science-fiction',
  'science-fiction/adaptations': 'science-fiction',
  'science-fiction/cyberpunk': 'science-fiction',
  'science-fiction/dystopian': 'science-fiction',
  'science-fiction/first-contact': 'science-fiction',
  'science-fiction/galactic-empire': 'science-fiction',
  'science-fiction/genetic-engineering': 'science-fiction',
  'science-fiction/military': 'science-fiction',
  'science-fiction/post-apocalyptic': 'science-fiction',
  'science-fiction/space-exploration': 'science-fiction',
  'science-fiction/space-opera': 'science-fiction',

  'fantasy/action-adventure': 'fantasy',
  'fantasy/adaptations': 'fantasy',
  'fantasy/dragons': 'fantasy',
  'fantasy/epic': 'fantasy',
  'fantasy/historical': 'fantasy',
  'fantasy/urban-paranormal': 'fantasy',

  'thriller/suspense': 'thriller',
  'thriller/psychological': 'thriller',
  'thriller/domestic': 'thriller',
  'thriller/historical': 'thriller',

  'mystery/amateur-sleuth': 'crime',
  'mystery/detective': 'crime',
  'mystery/historical': 'crime',
  'mystery/noir': 'crime',
  'mystery/private-investigator': 'crime',
  'mystery/traditional': 'crime',

  'romance/action-adventure': 'romance',
  'romance/comedy': 'romance',
  'romance/contemporary': 'romance',
  'romance/fantasy': 'romance',
  'romance/historical': 'romance',
  'romance/paranormal': 'romance',
  'romance/science-fiction': 'romance',
  'romance/sports': 'romance',
  'romance/suspense': 'romance',

  // Literary fiction is the one rack whose rungs genuinely change the shelf: a
  // sea adventure is an adventure and a play is a drama, whatever aisle Audible
  // files them under.
  'literary-fiction/action-adventure': 'adventure',
  'literary-fiction/classics': 'literary-fiction',
  'literary-fiction/coming-of-age': 'literary-fiction',
  'literary-fiction/contemporary': 'literary-fiction',
  'literary-fiction/drama': 'drama',
  'literary-fiction/family-life': 'literary-fiction',
  'literary-fiction/historical': 'historical-fiction',
  'literary-fiction/sagas': 'literary-fiction',
  'literary-fiction/sea-adventures': 'adventure',
  'literary-fiction/world-literature': 'literary-fiction',

  'biography/entertainment': 'biography',
  'history/europe': 'history',

  'children/action-adventure': 'adventure',
  'young-adult/literary-fiction': 'literary-fiction',
  'young-adult/romance': 'romance',
  'young-adult/science-fiction-fantasy': 'science-fiction',
  'young-adult/thriller': 'thriller',
}

/** Audible category id to Shiori genre, for every marketplace `audible-api-ts`
 *  knows the ids of — `audible.fr` and `audible.com` today.
 *
 *  Derived rather than typed out: the ids are eleven-digit numbers that mean
 *  nothing to read, one per shelf per marketplace, and the package already keeps
 *  them. A locale it learns next, Shiori gets for free.
 *
 *  Matching on the id and not on the name is the whole point. Audible's shelf
 *  names are translated per marketplace and reworded between seasons, so a table
 *  of names would need ten translations of the genre list and would still drift
 *  out from under us. An id is the same string tomorrow. */
const GENRE_BY_CATEGORY_ID: ReadonlyMap<string, Genre> = new Map(
  Object.entries(GENRE_CATEGORIES).flatMap(([shelf, idByLocale]) => {
    const genre = SHIORI_GENRE[shelf as AudibleGenre]
    if (!genre) return []
    return Object.values(idByLocale).map((id) => [id, genre] as const)
  }),
)

/** The genre an Audible title lands in, or nothing.
 *
 *  Each of Audible's category ladders runs root to leaf, and is read leaf first:
 *  "Science-Fiction et Fantasy > Fantasy > Épique" has to answer fantasy, which
 *  only the rungs below the joint rack can say. Ladders are tried in the order
 *  Amazon returns them, the first being the title's own aisle.
 *
 *  Nothing on no match, which is every marketplace outside `fr` and `com` as well
 *  as anything shelved somewhere Shiori has no word for. The book is then
 *  catalogued without a genre and the reader picks one on the book screen, which
 *  is what a book typed in by hand does too. */
export const genreFrom = (item: AudibleItem): Genre | undefined => {
  for (const ladder of item.categories ?? []) {
    for (let rung = ladder.categories.length - 1; rung >= 0; rung -= 1) {
      const genre = GENRE_BY_CATEGORY_ID.get(ladder.categories[rung].id)
      if (genre) return genre
    }
  }
  return undefined
}
