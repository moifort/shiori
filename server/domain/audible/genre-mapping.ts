import type { AudibleGenre, AudibleItem } from 'audible-api-ts'
import { GENRE_CATEGORIES } from 'audible-api-ts'
import { MAX_SUBGENRES, Subgenre } from '~/domain/book/primitives'
import type { Genre, LocalizedSubgenre } from '~/domain/book/types'

/** What one Audible shelf says about a book: the genre it belongs to, or — when
 *  the shelf is not a genre at all — the subgenre that records it anyway.
 *
 *  Every shelf says one or the other. There is no third case and no `undefined`:
 *  a shelf nobody decided about would go missing in silence, and the union is
 *  what forces the decision to be written down. */
type Shelf = { genre: Genre; generic?: true } | { subgenre: { fr: string; en: string } }

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
 *    young-adult thriller is a thriller filed under "Young Adult".
 *  - **A theme is not a genre either.** `lgbtq` and `sports` describe what a book
 *    is about across every rack, so they land in subgenres rather than being
 *    swept into `other`, which has to stay something the reader chose.
 *  - **Audible's shelf wins over the subject.** `romance/fantasy` is romance and
 *    `romance/science-fiction` is romance: that is the rack the reader bought
 *    from, and it is how they will look for it again.
 *  - **A generic rack only answers when nothing else does.** Amazon files half its
 *    catalogue under "Littérature, romans et fiction" beside the real shelf, and
 *    the joint "Science-Fiction et fantasy" rack is genuinely ambiguous. Those
 *    are marked `generic`: Fondation and Le Dernier vœu both sit on one, and
 *    neither is literary fiction. When a generic rack is all there is, the joint
 *    one answers `science-fiction`, the broader of the two.
 *
 *  The subgenre labels are written here rather than taken from Audible's own
 *  shelf name, for the same reason the ids are matched and the names are not: the
 *  name arrives translated per marketplace and reworded between seasons, and a
 *  library would end up carrying "Jeunesse" and "Children's" as two different
 *  subgenres. Each is written in every language the app speaks, as a book's
 *  subgenres are stored, so the import costs no translation call. */
const SHELF: Record<AudibleGenre, Shelf> = {
  'science-fiction': { genre: 'science-fiction' },
  fantasy: { genre: 'fantasy' },
  'science-fiction-fantasy': { genre: 'science-fiction', generic: true },
  // The joint crime-and-thriller rack is ambiguous as the SF-fantasy one is;
  // crime is where most of what it holds goes.
  'mystery-thriller-suspense': { genre: 'crime', generic: true },
  thriller: { genre: 'thriller' },
  mystery: { genre: 'crime' },
  'crime-fiction': { genre: 'crime' },
  horror: { genre: 'horror' },
  romance: { genre: 'romance' },
  'historical-fiction': { genre: 'historical-fiction' },
  'literary-fiction': { genre: 'literary-fiction', generic: true },
  biography: { genre: 'biography' },
  history: { genre: 'history' },
  business: { genre: 'business' },
  'self-help': { genre: 'self-help' },
  science: { genre: 'science' },
  children: { subgenre: { fr: 'Jeunesse', en: 'Children' } },
  'young-adult': { subgenre: { fr: 'Young Adult', en: 'Young Adult' } },
  comedy: { genre: 'humor' },
  erotica: { genre: 'romance' },
  religion: { genre: 'essay' },
  sports: { subgenre: { fr: 'Sport', en: 'Sports' } },
  travel: { genre: 'travel' },
  lgbtq: { subgenre: { fr: 'LGBTQ+', en: 'LGBTQ+' } },

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
  'fantasy/sword-sorcery': { genre: 'fantasy' },
  'fantasy/urban-paranormal': { genre: 'fantasy' },

  'thriller/suspense': { genre: 'thriller' },
  'thriller/psychological': { genre: 'thriller' },
  'thriller/domestic': { genre: 'thriller' },
  'thriller/historical': { genre: 'thriller' },

  'mystery/amateur-sleuth': { genre: 'crime' },
  'mystery/cozy': { genre: 'crime' },
  'mystery/detective': { genre: 'crime' },
  'mystery/hard-boiled': { genre: 'crime' },
  'mystery/historical': { genre: 'crime' },
  'mystery/noir': { genre: 'crime' },
  'mystery/police-procedural': { genre: 'crime' },
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
  'literary-fiction/classics': { genre: 'literary-fiction', generic: true },
  'literary-fiction/coming-of-age': { genre: 'literary-fiction' },
  'literary-fiction/contemporary': { genre: 'literary-fiction', generic: true },
  'literary-fiction/drama': { genre: 'drama' },
  'literary-fiction/family-life': { genre: 'literary-fiction' },
  'literary-fiction/fiction': { genre: 'literary-fiction', generic: true },
  'literary-fiction/historical': { genre: 'historical-fiction' },
  'literary-fiction/sagas': { genre: 'literary-fiction' },
  'literary-fiction/sea-adventures': { genre: 'adventure' },
  'literary-fiction/world-literature': { genre: 'literary-fiction', generic: true },

  'biography/entertainment': { genre: 'biography' },
  'history/europe': { genre: 'history' },

  'children/action-adventure': { genre: 'adventure' },
  'children/mystery': { genre: 'crime' },
  'children/science-fiction-fantasy': { genre: 'science-fiction', generic: true },
  'children/fantasy': { genre: 'fantasy' },
  'children/science-fiction': { genre: 'science-fiction' },
  'young-adult/literary-fiction': { genre: 'literary-fiction', generic: true },
  'young-adult/romance': { genre: 'romance' },
  'young-adult/science-fiction-fantasy': { genre: 'science-fiction', generic: true },
  'young-adult/fantasy': { genre: 'fantasy' },
  'young-adult/science-fiction': { genre: 'science-fiction' },
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

/** The shelves we recognize on each of the title's category ladders, leaf first
 *  within a ladder, ladders in the order Amazon returns them — the first being
 *  the title's own aisle.
 *
 *  Leaf first is what lets the rung below a joint rack decide: "Science-Fiction
 *  et Fantasy > Fantasy > Épique" has to answer fantasy, and only the rungs below
 *  the joint rack can say so.
 *
 *  Empty for every marketplace outside `fr` and `com`, whose ids are unknown. */
const laddersOf = (item: AudibleItem): Shelf[][] =>
  (item.categories ?? []).map((ladder) =>
    ladder.categories.toReversed().flatMap((category) => {
      const shelf = SHELF_BY_CATEGORY_ID.get(category.id)
      return shelf ? [shelf] : []
    }),
  )

/** What one ladder says the book is: its most precise genre, a specific rack
 *  before a generic one wherever it sits on the ladder. */
const voteOf = (ladder: readonly Shelf[]): { genre: Genre; generic: boolean } | undefined => {
  const genres = ladder.flatMap((shelf) => ('genre' in shelf ? [shelf] : []))
  const chosen = genres.find((shelf) => !shelf.generic) ?? genres[0]
  return chosen && { genre: chosen.genre, generic: chosen.generic === true }
}

/** The genre an Audible title lands in, or nothing.
 *
 *  Every ladder votes, and the genre most of them name wins. Taking the first
 *  ladder instead let the catch-all "Littérature, romans et fiction" decide for
 *  whatever Amazon happened to list first. Generic racks vote only when no
 *  ladder names anything more precise; a tie goes to the earlier ladder.
 *
 *  Nothing when no shelf is recognized, and nothing when every shelf it sits on
 *  is an audience or a theme. The book is then catalogued without a genre and the
 *  reader picks one on the book screen, which is what a book typed in by hand
 *  does too — but `subgenresFrom` has still kept what those shelves said. */
export const genreFrom = (item: AudibleItem): Genre | undefined => {
  const votes = laddersOf(item).flatMap((ladder) => voteOf(ladder) ?? [])
  const specific = votes.filter((vote) => !vote.generic)
  const counted = specific.length > 0 ? specific : votes
  const tally = new Map<Genre, number>()
  for (const { genre } of counted) tally.set(genre, (tally.get(genre) ?? 0) + 1)
  // A Map keeps insertion order and only a strictly greater count replaces the
  // leader, so a tie stays with the earlier ladder.
  let winner: Genre | undefined
  for (const [genre, count] of tally) {
    if (winner === undefined || count > (tally.get(winner) ?? 0)) winner = genre
  }
  return winner
}

/** What the title's shelves say that no genre can hold.
 *
 *  An audience and a theme are not genres, so they would be dropped outright —
 *  yet "Jeunesse" is exactly the kind of label a subgenre is for, and the scan
 *  names it as one of its own examples. They are kept here instead.
 *
 *  Collected whether or not a genre was found, because the two answer different
 *  questions: a young-adult thriller is a thriller, filed under "Young Adult".
 *  Deduplicated — a title sits on several ladders and they overlap — and capped
 *  at `MAX_SUBGENRES`, in the order the ladders gave them, since the first is the
 *  only one the library list shows. */
export const subgenresFrom = (item: AudibleItem): LocalizedSubgenre[] => {
  const shelves = laddersOf(item)
    .flat()
    .flatMap((shelf) => ('subgenre' in shelf ? [shelf.subgenre] : []))
  return [...new Map(shelves.map((shelf) => [shelf.en, shelf])).values()]
    .slice(0, MAX_SUBGENRES)
    .map(({ fr, en }) => ({ fr: Subgenre(fr), en: Subgenre(en) }))
}
