/**
 * Downloads the covers the showcase library draws, into `screenshots/covers/`.
 *
 * The App Store captures show a reader's library (`ios/Shiori/Shared/Showcase.swift`),
 * and a library of grey initials sells nothing. Each cover is the French edition's,
 * found through the iTunes Search API, which answers without a key or a quota and
 * serves the artwork at any size. Open Library knows few recent French editions and
 * Google Books refuses anonymous callers once its daily quota is spent.
 *
 * The files are committed: the captures must not depend on a store search answering
 * the same way twice. Run again only to add or replace a cover; a slug already on
 * disk is kept unless `--force` is given.
 *
 * Usage: bun scripts/showcase-covers.ts [--force]
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
  media?: 'ebook' | 'audiobook'
}

const volumes = (slug: string, term: string, match: (n: number) => string, numbers: number[]) =>
  numbers.map((n) => ({
    slug: `${slug}-${String(n).padStart(2, '0')}`,
    term: `${term} ${n}`,
    match: match(n),
  }))

const COVERS: Cover[] = [
  // The first volumes are sold under another listing than the recent ones.
  ...volumes('one-piece', 'one piece tome', (n) => `one piece tome ${n}`, [1, 2, 3, 4, 5, 6]).map(
    (cover) => ({ ...cover, term: `${cover.term} oda` }),
  ),
  ...volumes(
    'one-piece',
    'one piece édition originale tome',
    (n) => `one piece originale tome ${n}`,
    [109, 110, 111, 112, 113, 114],
  ),
  ...volumes(
    'frieren',
    'frieren t',
    (n) => `frieren t${String(n).padStart(2, '0')}`,
    [1, 2, 3, 4, 5, 6, 12, 13, 14, 15],
  ).map((cover) => ({ ...cover, term: `frieren ${cover.match.split(' ')[1]}` })),
  ...volumes(
    'blue-lock',
    'blue lock',
    (n) => `blue lock t${String(n).padStart(2, '0')}`,
    [1, 2, 3, 4, 5, 6, 32, 33, 34, 35],
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

const force = process.argv.includes('--force')
const target = join(import.meta.dir, '../screenshots/covers')
await mkdir(target, { recursive: true })

/** Lower case, no accents, no punctuation: what a reader would call the same title. */
const plain = (text: string) =>
  text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLocaleLowerCase('fr')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()

type Result = { trackName?: string; collectionName?: string; artworkUrl100?: string }

/** The store answers some twenty searches a minute, then "Rate limit exceeded" in
 *  plain text: each search waits its turn, and one refused waits a minute more. */
async function search(url: string): Promise<{ results: Result[] }> {
  for (let attempt = 0; ; attempt += 1) {
    await Bun.sleep(3_500)
    const response = await fetch(url)
    const body = await response.text()
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
for (const cover of COVERS) {
  const file = join(target, `${cover.slug}.jpg`)
  if (!force && (await Bun.file(file).exists())) continue

  const media = cover.media ?? 'ebook'
  const url = `https://itunes.apple.com/search?${new URLSearchParams({
    term: cover.term,
    country: 'fr',
    media,
    limit: '25',
  })}`
  const { results } = await search(url)
  const words = plain(cover.match).split(' ')
  const found = results.find((result) => {
    const title = plain(`${result.trackName ?? ''} ${result.collectionName ?? ''}`)
    const tokens = title.split(' ')
    const avoided = plain(cover.avoid ?? '')
      .split(' ')
      .filter(Boolean)
    return (
      words.every((word) => tokens.includes(word)) &&
      !avoided.some((word) => tokens.includes(word)) &&
      result.artworkUrl100
    )
  })
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
