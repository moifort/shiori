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
    return results.find((result) => {
      const tokens = plain(`${result.trackName ?? ''} ${result.collectionName ?? ''}`).split(' ')
      return (
        words.every((word) => tokens.includes(word)) &&
        !avoided.some((word) => tokens.includes(word)) &&
        // A pre-order shows a grey placeholder with its title, not its cover.
        !(result.releaseDate && new Date(result.releaseDate) > new Date()) &&
        result.artworkUrl100
      )
    })
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
