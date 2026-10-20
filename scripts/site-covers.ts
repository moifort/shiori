/**
 * Bundles the classics on the landing page's wall of covers, next to the showcase
 * library's own. The science-fiction ones are each pinned to an Open Library
 * cover picked by eye for a coloured, legible edition: a search turns up library
 * stickers, barcodes and thumbnails as readily as a real cover. The great French
 * novels are the showcase's (`scripts/showcase-covers.ts`), so the page and the
 * app's captures show the same editions.
 *
 * The covers are kept in `site/covers/`, never hotlinked: the page loads them
 * from its own host, and Open Library is asked once, here, not by every visitor.
 * Each is shrunk to the height the wall draws it at on a 2× screen.
 *
 * Usage: bun scripts/site-covers.ts
 */

import { rm } from 'node:fs/promises'
import { join } from 'node:path'

const CLASSICS: { slug: string; coverId: number }[] = [
  { slug: 'sf-1984', coverId: 8745958 },
  { slug: 'sf-2001', coverId: 15170836 },
  { slug: 'sf-ancillary-justice', coverId: 7355949 },
  { slug: 'sf-androids-dream', coverId: 207515 },
  { slug: 'sf-annihilation', coverId: 8408974 },
  { slug: 'sf-brave-new-world', coverId: 8231823 },
  { slug: 'sf-canticle-leibowitz', coverId: 10221348 },
  { slug: 'sf-children-of-time', coverId: 8264706 },
  { slug: 'sf-dispossessed', coverId: 6979680 },
  { slug: 'sf-enders-game', coverId: 12996033 },
  { slug: 'sf-fahrenheit-451', coverId: 12993656 },
  { slug: 'sf-forever-war', coverId: 10693768 },
  { slug: 'sf-fourmis', coverId: 975427 },
  { slug: 'sf-handmaids-tale', coverId: 8231851 },
  { slug: 'sf-high-castle', coverId: 420452 },
  { slug: 'sf-hitchhiker', coverId: 12986869 },
  { slug: 'sf-klara', coverId: 10648686 },
  { slug: 'sf-left-hand-darkness', coverId: 10618463 },
  { slug: 'sf-leviathan-wakes', coverId: 7314237 },
  { slug: 'sf-martian', coverId: 11447888 },
  { slug: 'sf-monde-des-a', coverId: 981970 },
  { slug: 'sf-murderbot', coverId: 9157148 },
  { slug: 'sf-neuromancer', coverId: 283860 },
  { slug: 'sf-nuit-des-temps', coverId: 9245348 },
  { slug: 'sf-planete-singes', coverId: 1009545 },
  { slug: 'sf-rama', coverId: 13472608 },
  { slug: 'sf-ready-player-one', coverId: 8737626 },
  { slug: 'sf-slaughterhouse-five', coverId: 12727001 },
  { slug: 'sf-snow-crash', coverId: 392508 },
  { slug: 'sf-solaris', coverId: 12313764 },
  { slug: 'sf-stars-destination', coverId: 911114 },
  { slug: 'sf-starship-troopers', coverId: 14630746 },
  { slug: 'sf-station-eleven', coverId: 7369961 },
  { slug: 'sf-stranger-strange-land', coverId: 14630668 },
  { slug: 'sf-the-road', coverId: 198120 },
  { slug: 'sf-time-machine', coverId: 9009316 },
  { slug: 'sf-war-of-the-worlds', coverId: 36314 },
  { slug: 'sf-wool', coverId: 14369537 },
]

/** The French novels the showcase library holds, under `screenshots/covers/`. */
const FRENCH_NOVELS = [
  'miserables',
  'madame-bovary',
  'rouge-et-noir',
  'germinal',
  'etranger',
  'peste',
  'petit-prince',
  'bel-ami',
  'notre-dame',
  'trois-mousquetaires',
  'candide',
  'pere-goriot',
  'vingt-mille-lieues',
  'promesse-de-l-aube',
  'anomalie',
  'liaisons-dangereuses',
  'swann',
]

/** The wall draws a cover up to 136 pt wide, 204 pt high: 400 px covers a 2× screen. */
const HEIGHT_PX = 400
const target = join(import.meta.dir, '../site/covers')
const showcase = join(import.meta.dir, '../screenshots/covers')

/** `sips` ships with macOS and re-encodes whatever it is given as a small JPEG. */
const shrink = (source: string, file: string) =>
  Bun.spawnSync([
    'sips',
    '--resampleHeight',
    String(HEIGHT_PX),
    '-s',
    'format',
    'jpeg',
    '-s',
    'formatOptions',
    '72',
    source,
    '--out',
    file,
  ]).exitCode === 0

let written = 0
for (const { slug, coverId } of CLASSICS) {
  const response = await fetch(`https://covers.openlibrary.org/b/id/${coverId}-L.jpg`)
  if (!response.ok) {
    process.stdout.write(`skipped ${response.status}  ${slug}\n`)
    continue
  }
  const file = join(target, `${slug}.jpg`)
  await Bun.write(`${file}.source`, await response.arrayBuffer())
  const shrunk = shrink(`${file}.source`, file)
  await rm(`${file}.source`)
  if (!shrunk) {
    process.stdout.write(`unreadable   ${slug}\n`)
    continue
  }
  written += 1
  process.stdout.write(`${slug}\n`)
}

for (const slug of FRENCH_NOVELS) {
  if (!shrink(join(showcase, `${slug}.jpg`), join(target, `fr-${slug}.jpg`))) {
    process.stdout.write(`unreadable   ${slug}\n`)
    continue
  }
  written += 1
  process.stdout.write(`fr-${slug}\n`)
}

process.stdout.write(`\n${written} covers in site/covers\n`)
