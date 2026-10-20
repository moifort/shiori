/**
 * Downloads the covers the showcase library draws, into `screenshots/covers/`, and
 * those of its English editions into `screenshots/covers/en/`.
 *
 * The App Store captures show a reader's library (`ios/Shiori/Shared/Showcase.swift`),
 * and a library of grey initials sells nothing. Each cover is the French edition's,
 * found through the iTunes Search API, which answers without a key or a quota and
 * serves the artwork at any size. The English captures show the American editions,
 * from the American store; a slug missing there draws its French cover. Open Library knows few recent French editions and
 * Google Books refuses anonymous callers once its daily quota is spent.
 *
 * The files are committed: the captures must not depend on a store search answering
 * the same way twice. Run again only to add or replace a cover; a slug already on
 * disk is kept unless `--force` is given.
 *
 * Usage: bun scripts/showcase-covers.ts [--language en] [--force]
 */
import { mkdir } from 'node:fs/promises'
import { join } from 'node:path'

type Cover = {
  /** The file name, and what `Showcase.swift` names the cover by. */
  slug: string
  term: string
  /** Every word of it must appear in the title the store returns. */
  match: string
  /** Words that rule a title out: a spin-off shares its series' name. */
  avoid?: string
  /** A second search, for a volume the first one does not reach. */
  alternative?: string
  /** The edition to take among those that match, from 0: a classic is sold in
   *  bare reprints with a plain coloured cover as readily as in a real one. */
  nth?: number
  media?: 'ebook' | 'audiobook'
}

const range = (first: number, last: number) =>
  Array.from({ length: last - first + 1 }, (_, index) => first + index)

const volumes = (slug: string, term: string, match: (n: number) => string, numbers: number[]) =>
  numbers.map((n) => ({
    slug: `${slug}-${String(n).padStart(2, '0')}`,
    term: `${term} ${n}`,
    match: match(n),
  }))

const COVERS: Cover[] = [
  // Every volume of the long sagas: the library's mosaic draws dozens at once.
  // One Piece's first volumes and its recent ones are sold under two listings.
  ...volumes('one-piece', 'one piece tome', (n) => `one piece tome ${n}`, range(1, 114)).map(
    (cover) => ({
      ...cover,
      term: `${cover.term} oda`,
      alternative: cover.term.replace('one piece tome', 'one piece édition originale tome'),
    }),
  ),
  ...volumes(
    'frieren',
    'frieren t',
    (n) => `frieren t${String(n).padStart(2, '0')}`,
    range(1, 15),
  ).map((cover) => ({ ...cover, term: cover.match })),
  ...volumes(
    'blue-lock',
    'blue lock',
    (n) => `blue lock t${String(n).padStart(2, '0')}`,
    range(1, 35),
  ).map((cover) => ({ ...cover, term: cover.match, avoid: 'nagi anniversaire' })),
  ...volumes('blacksad', 'blacksad tome', (n) => `blacksad tome ${n}`, [1, 2, 3, 4, 5, 6, 7]).map(
    (cover) =>
      cover.slug === 'blacksad-06'
        ? { ...cover, term: 'blacksad alors tout tombe', match: 'alors tout tombe premiere' }
        : cover,
  ),
  ...volumes(
    'chateau-animaux',
    'le château des animaux tome',
    (n) => `animaux tome ${n}`,
    [1, 2, 3, 4],
  ),
  ...volumes('spy-family', 'spy x family tome', (n) => `spy family tome ${n}`, [1]),
  { slug: 'nom-du-vent', term: 'le nom du vent rothfuss', match: 'nom du vent' },
  { slug: 'peur-du-sage', term: 'la peur du sage rothfuss', match: 'peur du sage premiere' },
  { slug: 'dune', term: 'dune tome 1 herbert', match: 'dune tome 1' },
  { slug: 'messie-de-dune', term: 'messie de dune', match: 'messie de dune' },
  { slug: 'trois-corps', term: 'le problème à trois corps liu', match: 'probleme a trois corps' },
  { slug: 'foret-sombre', term: 'la forêt sombre liu', match: 'foret sombre' },
  { slug: 'mort-immortelle', term: 'la mort immortelle liu', match: 'mort immortelle' },
  {
    slug: 'projet-derniere-chance',
    term: 'projet dernière chance weir',
    match: 'projet derniere chance',
  },
  {
    slug: 'horde-du-contrevent',
    term: 'la horde du contrevent damasio',
    match: 'horde du contrevent',
  },
  { slug: 'furtifs', term: 'les furtifs damasio', match: 'furtifs' },
  { slug: 'veiller-sur-elle', term: 'veiller sur elle andrea', match: 'veiller sur elle' },
  { slug: 'jacaranda', term: 'jacaranda gaël faye', match: 'jacaranda' },
  { slug: 'hyperion', term: 'hypérion simmons', match: 'hyperion tome 1' },
  { slug: 'fondation', term: 'fondation asimov', match: 'fondation tome 1' },
  { slug: 'fourth-wing', term: 'fourth wing yarros', match: 'fourth wing francaise' },
  { slug: 'demain-et-demain', term: 'demain et demain et demain zevin', match: 'demain et demain' },
  { slug: 'sapiens', term: 'sapiens harari', match: 'sapiens 2022' },
  { slug: 'shibumi', term: 'shibumi trevanian', match: 'shibumi' },
  { slug: 'monte-cristo', term: 'le comte de monte-cristo dumas', match: 'monte cristo tome i' },
  { slug: 'sorceleur-01', term: 'sorceleur dernier voeu', match: 'sorceleur dernier voeu' },
  // The science-fiction classics and the great French novels, so the shelf
  // reads as a reader's, not as a manga collection.
  { slug: '1984', term: '1984 orwell', match: '1984' },
  {
    slug: 'meilleur-des-mondes',
    term: 'le meilleur des mondes aldous huxley',
    match: 'meilleur des mondes',
    avoid: 'retour fiche analyse etude universalis',
  },
  { slug: 'fahrenheit-451', term: 'fahrenheit 451 bradbury', match: 'fahrenheit 451' },
  { slug: 'neuromancien', term: 'neuromancien gibson', match: 'neuromancien' },
  {
    slug: 'androides',
    term: 'blade runner philip k dick',
    match: 'blade runner',
    avoid: 'exegesis',
  },
  { slug: 'ender', term: 'la stratégie ender card', match: 'strategie ender' },
  // Rendez-vous avec Rama is not sold as a French ebook: Ravage stands in for it.
  { slug: 'rama', term: 'ravage barjavel', match: 'ravage', avoid: 'tome fiche analyse' },
  { slug: 'solaris', term: 'solaris lem', match: 'solaris' },
  // The month's discoveries: books the shelf does not hold, chosen from it.
  { slug: 'toile-du-temps', term: 'dans la toile du temps tchaikovsky', match: 'toile du temps' },
  {
    slug: 'main-gauche-nuit',
    term: 'la main gauche de la nuit le guin',
    match: 'main gauche de la nuit',
  },
  { slug: 'leviathan', term: 'eveil du leviathan corey', match: 'eveil du leviathan' },
  { slug: 'ubik', term: 'ubik philip k dick', match: 'ubik' },
  { slug: 'fourmis', term: 'les fourmis werber', match: 'fourmis' },
  { slug: 'planete-des-singes', term: 'la planète des singes boulle', match: 'planete des singes' },
  { slug: 'nuit-des-temps', term: 'la nuit des temps barjavel', match: 'nuit des temps' },
  { slug: 'seul-sur-mars', term: 'seul sur mars weir', match: 'seul sur mars' },
  { slug: 'silo', term: 'silo hugh howey', match: 'silo', avoid: 'origines generations' },
  {
    slug: 'guide-galactique',
    term: 'le guide du voyageur galactique adams',
    match: 'guide du voyageur galactique',
  },
  {
    slug: 'chroniques-martiennes',
    term: 'chroniques martiennes bradbury',
    match: 'chroniques martiennes',
  },
  { slug: 'station-eleven', term: 'station eleven mandel', match: 'station eleven' },
  { slug: 'murderbot', term: 'défaillances systèmes martha wells', match: 'defaillances systemes' },
  { slug: 'depossedes', term: 'les dépossédés le guin', match: 'depossedes' },
  { slug: 'servante-ecarlate', term: 'la servante écarlate atwood', match: 'servante ecarlate' },
  { slug: 'miserables', term: 'les misérables folio', match: 'miserables tome 1' },
  { slug: 'madame-bovary', term: 'madame bovary flaubert', match: 'madame bovary' },
  {
    slug: 'rouge-et-noir',
    term: 'le rouge et le noir stendhal',
    match: 'rouge et le noir',
    nth: 1,
  },
  { slug: 'germinal', term: 'germinal livre de poche', match: 'germinal', avoid: 'abrege' },
  { slug: 'etranger', term: "l'étranger camus", match: 'etranger' },
  { slug: 'peste', term: 'la peste camus', match: 'peste' },
  { slug: 'petit-prince', term: 'le petit prince saint-exupéry', match: 'petit prince' },
  { slug: 'bel-ami', term: 'bel-ami livre de poche', match: 'bel ami' },
  {
    slug: 'notre-dame',
    term: 'notre-dame de paris livre de poche',
    match: 'notre dame de paris',
    avoid: 'abrege',
  },
  {
    slug: 'trois-mousquetaires',
    term: 'les trois mousquetaires alexandre dumas',
    match: 'trois mousquetaires',
    nth: 1,
  },
  { slug: 'candide', term: 'candide ou l optimisme voltaire', match: 'candide', nth: 1 },
  {
    slug: 'pere-goriot',
    term: 'le père goriot livre de poche',
    match: 'pere goriot',
    avoid: 'abrege',
  },
  {
    slug: 'vingt-mille-lieues',
    term: 'vingt mille lieues sous les mers verne',
    match: 'vingt mille lieues',
    avoid: 'bibliocollege analyse fiche',
  },
  { slug: 'promesse-de-l-aube', term: "la promesse de l'aube gary", match: 'promesse de l aube' },
  { slug: 'anomalie', term: "l'anomalie le tellier", match: 'anomalie' },
  {
    slug: 'liaisons-dangereuses',
    term: 'les liaisons dangereuses laclos',
    match: 'liaisons dangereuses',
  },
  {
    slug: 'swann',
    term: 'du côté de chez swann marcel proust',
    match: 'cote de chez swann',
    nth: 6,
  },
  // Read on a Kindle: the French edition exists as an ebook only up to its
  // sixth volume.
  ...[
    'dungeon crawler carl tome 1',
    'ogive jugement dernier',
    'recettes anarchiste',
    'portail dieux infernaux',
    'mascarade boucher',
    'veuve chaos',
  ].map((match, index) => ({
    slug: `dcc-${String(index + 1).padStart(2, '0')}`,
    term: `dungeon crawler carl ${match}`,
    match,
  })),
  // Heard rather than read: the audio saga, square covers.
  ...['hyperion 1', 'chute hyperion 2', 'endymion hyperion 3', 'eveil endymion 4'].map(
    (match, index) => ({
      slug: `hyperion-audio-${String(index + 1).padStart(2, '0')}`,
      term: `${match} simmons`,
      match,
      media: 'audiobook' as const,
    }),
  ),
]

/** The American editions, under the same slugs: `Showcase.swift` swaps the
 *  French books it has no English edition of for others, kept on those slugs. */
const ENGLISH_COVERS: Cover[] = [
  // The last volumes are not out in English yet: their French covers stand in.
  ...volumes('one-piece', 'one piece vol', (n) => `one piece vol ${n}`, range(1, 112)).map(
    (cover) => ({ ...cover, term: `${cover.term} oda`, alternative: cover.term }),
  ),
  ...volumes(
    'frieren',
    'frieren beyond journey s end vol',
    (n) => `frieren vol ${n}`,
    range(1, 14),
  ),
  ...volumes('blue-lock', 'blue lock volume', (n) => `blue lock volume ${n}`, range(1, 35)),
  ...volumes('blacksad', 'blacksad volume', (n) => `blacksad volume ${n}`, range(1, 7)),
  // Le Château des Animaux has no American edition: Saga stands in for it.
  ...volumes('chateau-animaux', 'saga vol', (n) => `saga vol ${n}`, range(1, 4)).map((cover) => ({
    ...cover,
    term: `${cover.term} vaughan`,
    avoid: 'deluxe compendium',
  })),
  ...volumes('spy-family', 'spy x family vol', (n) => `spy family vol ${n}`, [1]),
  { slug: 'nom-du-vent', term: 'the name of the wind rothfuss', match: 'name of the wind' },
  { slug: 'peur-du-sage', term: 'the wise man s fear rothfuss', match: 'wise man s fear' },
  {
    slug: 'dune',
    term: 'dune frank herbert',
    match: 'dune',
    avoid: 'messiah children god emperor',
  },
  { slug: 'messie-de-dune', term: 'dune messiah herbert', match: 'dune messiah' },
  { slug: 'trois-corps', term: 'the three body problem liu', match: 'three body problem' },
  { slug: 'foret-sombre', term: 'the dark forest cixin liu', match: 'dark forest' },
  { slug: 'mort-immortelle', term: 'death s end cixin liu', match: 'death s end' },
  { slug: 'projet-derniere-chance', term: 'project hail mary weir', match: 'project hail mary' },
  { slug: 'horde-du-contrevent', term: 'the way of kings sanderson', match: 'way of kings' },
  { slug: 'furtifs', term: 'the left hand of darkness le guin', match: 'left hand of darkness' },
  { slug: 'veiller-sur-elle', term: 'lessons in chemistry garmus', match: 'lessons in chemistry' },
  { slug: 'hyperion', term: 'hyperion dan simmons', match: 'hyperion', avoid: 'fall' },
  { slug: 'fondation', term: 'foundation isaac asimov', match: 'foundation' },
  { slug: 'fourth-wing', term: 'fourth wing yarros', match: 'fourth wing' },
  {
    slug: 'demain-et-demain',
    term: 'tomorrow and tomorrow and tomorrow zevin',
    match: 'tomorrow and tomorrow',
  },
  { slug: 'sapiens', term: 'sapiens harari', match: 'sapiens' },
  { slug: 'shibumi', term: 'shibumi trevanian', match: 'shibumi' },
  { slug: 'monte-cristo', term: 'the count of monte cristo dumas', match: 'count of monte cristo' },
  { slug: 'sorceleur-01', term: 'the last wish sapkowski', match: 'last wish' },
  { slug: '1984', term: '1984 george orwell', match: '1984' },
  {
    slug: 'meilleur-des-mondes',
    term: 'brave new world huxley',
    match: 'brave new world',
    avoid: 'revisited',
  },
  { slug: 'fahrenheit-451', term: 'fahrenheit 451 bradbury', match: 'fahrenheit 451' },
  { slug: 'neuromancien', term: 'neuromancer gibson', match: 'neuromancer' },
  {
    slug: 'androides',
    term: 'do androids dream of electric sheep dick',
    match: 'androids dream electric sheep',
  },
  { slug: 'ender', term: 'enders game orson scott card', match: 'ender s game', avoid: 'shadow' },
  { slug: 'rama', term: 'rendezvous with rama clarke', match: 'rendezvous with rama' },
  { slug: 'solaris', term: 'solaris stanislaw lem', match: 'solaris' },
  { slug: 'toile-du-temps', term: 'children of time tchaikovsky', match: 'children of time' },
  {
    slug: 'main-gauche-nuit',
    term: 'the left hand of darkness le guin',
    match: 'left hand of darkness',
  },
  { slug: 'leviathan', term: 'leviathan wakes corey', match: 'leviathan wakes' },
  { slug: 'ubik', term: 'ubik philip k dick', match: 'ubik' },
  // Two French novels the American store lacks give their place to Flowers for
  // Algernon and Childhood's End.
  {
    slug: 'fourmis',
    term: 'flowers for algernon keyes',
    match: 'flowers for algernon',
    avoid: 'study guide sparknotes trivia facts english',
  },
  {
    slug: 'planete-des-singes',
    term: 'planet of the apes pierre boulle',
    match: 'planet of the apes',
  },
  {
    slug: 'nuit-des-temps',
    term: 'childhood s end clarke',
    match: 'childhood s end',
    avoid: 'sparknotes',
  },
  { slug: 'seul-sur-mars', term: 'the martian andy weir', match: 'martian', avoid: 'chronicles' },
  { slug: 'silo', term: 'wool hugh howey', match: 'wool', avoid: 'shift dust' },
  {
    slug: 'guide-galactique',
    term: 'the hitchhiker s guide to the galaxy adams',
    match: 'hitchhiker s guide to the galaxy',
    avoid: 'ultimate complete trilogy',
  },
  {
    slug: 'chroniques-martiennes',
    term: 'the martian chronicles bradbury',
    match: 'martian chronicles',
  },
  { slug: 'station-eleven', term: 'station eleven mandel', match: 'station eleven' },
  { slug: 'murderbot', term: 'all systems red martha wells', match: 'all systems red' },
  { slug: 'depossedes', term: 'the dispossessed le guin', match: 'dispossessed' },
  {
    slug: 'servante-ecarlate',
    term: 'the handmaid s tale atwood',
    match: 'handmaid s tale',
    avoid: 'graphic',
  },
  { slug: 'miserables', term: 'les miserables victor hugo', match: 'miserables' },
  { slug: 'madame-bovary', term: 'madame bovary flaubert', match: 'madame bovary' },
  { slug: 'rouge-et-noir', term: 'the red and the black stendhal', match: 'red and the black' },
  { slug: 'germinal', term: 'germinal zola', match: 'germinal' },
  { slug: 'etranger', term: 'the stranger albert camus', match: 'stranger' },
  { slug: 'peste', term: 'the plague albert camus', match: 'plague' },
  { slug: 'petit-prince', term: 'the little prince saint-exupery', match: 'little prince' },
  { slug: 'bel-ami', term: 'bel-ami maupassant', match: 'bel ami' },
  {
    slug: 'notre-dame',
    term: 'the hunchback of notre-dame hugo',
    match: 'hunchback of notre dame',
  },
  {
    slug: 'trois-mousquetaires',
    term: 'the three musketeers penguin classics',
    match: 'three musketeers',
    nth: 5,
  },
  { slug: 'candide', term: 'candide voltaire', match: 'candide' },
  { slug: 'pere-goriot', term: 'pere goriot balzac', match: 'goriot' },
  {
    slug: 'vingt-mille-lieues',
    term: 'twenty thousand leagues under the sea verne',
    match: 'twenty thousand leagues',
  },
  { slug: 'promesse-de-l-aube', term: 'promise at dawn romain gary', match: 'promise at dawn' },
  { slug: 'anomalie', term: 'the anomaly le tellier', match: 'anomaly' },
  { slug: 'liaisons-dangereuses', term: 'dangerous liaisons laclos', match: 'dangerous liaisons' },
  { slug: 'swann', term: 'swann s way penguin classics', match: 'swann s way', nth: 2 },
  ...[
    'dungeon crawler carl',
    'carl s doomsday scenario',
    'dungeon anarchist s cookbook',
    'gate of the feral gods',
    'butcher s masquerade',
    'eye of the bedlam bride',
  ].map((match, index) => ({
    slug: `dcc-${String(index + 1).padStart(2, '0')}`,
    term: `${match} dinniman`,
    match,
    // A reading guide shares the sixth's title.
    avoid: 'after reading summary guide',
    // The store sells the sixth as a recording only.
    ...(index === 5 ? { media: 'audiobook' as const } : {}),
  })),
  ...['hyperion', 'fall of hyperion', 'endymion', 'rise of endymion'].map((match, index) => ({
    slug: `hyperion-audio-${String(index + 1).padStart(2, '0')}`,
    term: `${match} simmons`,
    match: `${match} unabridged`,
    avoid: index === 0 ? 'fall' : index === 2 ? 'rise' : undefined,
    media: 'audiobook' as const,
  })),
]

const english =
  process.argv.includes('--language') &&
  process.argv[process.argv.indexOf('--language') + 1] === 'en'

const force = process.argv.includes('--force')
const target = join(import.meta.dir, '../screenshots/covers', english ? 'en' : '')
await mkdir(target, { recursive: true })

/** Lower case, no accents, no punctuation: what a reader would call the same title. */
const plain = (text: string) =>
  text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLocaleLowerCase('fr')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()

type Result = {
  trackName?: string
  collectionName?: string
  artworkUrl100?: string
  releaseDate?: string
}

/** The store answers some twenty searches a minute, then "Rate limit exceeded" in
 *  plain text: each search waits its turn, and one refused waits a minute more. */
async function search(url: string): Promise<{ results: Result[] }> {
  for (let attempt = 0; ; attempt += 1) {
    await Bun.sleep(3_500)
    const response = await fetch(url)
    const body = await response.text()
    // Some searches break the store itself, every time: as good as no answer.
    if (body.includes('newNullResponse')) return { results: [] }
    try {
      return JSON.parse(body) as { results: Result[] }
    } catch {
      if (attempt >= 3) throw new Error(`the store keeps refusing: ${body.slice(0, 80)}`)
      process.stdout.write('rate limited, waiting a minute\n')
      await Bun.sleep(60_000)
    }
  }
}

let missing = 0
for (const cover of english ? ENGLISH_COVERS : COVERS) {
  const file = join(target, `${cover.slug}.jpg`)
  if (!force && (await Bun.file(file).exists())) continue

  const media = cover.media ?? 'ebook'
  const words = plain(cover.match).split(' ')
  const avoided = plain(cover.avoid ?? '')
    .split(' ')
    .filter(Boolean)
  const lookFor = async (term: string) => {
    const url = `https://itunes.apple.com/search?${new URLSearchParams({
      term,
      country: english ? 'us' : 'fr',
      media,
      limit: '25',
    })}`
    const { results } = await search(url)
    const matching = results.filter((result) => {
      const tokens = plain(`${result.trackName ?? ''} ${result.collectionName ?? ''}`).split(' ')
      return (
        words.every((word) => tokens.includes(word)) &&
        !avoided.some((word) => tokens.includes(word)) &&
        // A pre-order shows a grey placeholder with its title, not its cover.
        !(result.releaseDate && new Date(result.releaseDate) > new Date()) &&
        result.artworkUrl100
      )
    })
    return matching[cover.nth ?? 0]
  }
  const found =
    (await lookFor(cover.term)) ??
    (cover.alternative ? await lookFor(cover.alternative) : undefined)
  if (!found?.artworkUrl100) {
    missing += 1
    process.stdout.write(`not found    ${cover.slug}\n`)
    continue
  }
  // The artwork path ends in its size, and the store draws any other one asked
  // for within the cover's own proportions.
  const size = media === 'audiobook' ? '900x900bb' : '600x900bb'
  const response = await fetch(found.artworkUrl100.replace(/\d+x\d+bb/, size))
  if (!response.ok) {
    missing += 1
    process.stdout.write(`skipped ${response.status}  ${cover.slug}\n`)
    continue
  }
  await Bun.write(file, await response.arrayBuffer())
  // Re-encoded smaller: the covers are committed, and a capture shows none of
  // them larger than a third of the screen.
  Bun.spawnSync([
    'sips',
    '--resampleHeight',
    '720',
    '-s',
    'format',
    'jpeg',
    '-s',
    'formatOptions',
    '70',
    file,
    '--out',
    file,
  ])
  process.stdout.write(`${cover.slug.padEnd(24)} ${found.trackName ?? found.collectionName}\n`)
}

process.stdout.write(missing === 0 ? '\nevery cover is on disk\n' : `\n${missing} missing\n`)
if (missing > 0) process.exit(1)
