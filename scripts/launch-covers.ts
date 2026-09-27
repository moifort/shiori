/**
 * Bundles the covers that drift behind the icon while the app opens: a few of a
 * reader's own books, named by title, and the great classics, from Open Library.
 * Downloads each cover, shrinks it to the size the opening draws, and writes it
 * to `ios/Shiori/LaunchCovers/`, replacing whatever was there. The app picks up
 * every `launch-cover-*.jpg` it ships with, and gives every row of the opening
 * covers of its own, so the set wants forty or more.
 *
 * Only published covers are taken, never a reader's photo: whatever lands in the
 * folder ships to everyone who installs the app, and a photo shows a hand, a
 * table, a room.
 *
 * Runs from the Mac with the gcloud application default credentials
 * (`gcloud auth application-default login`). The reader is named by uid or by
 * the email of their account.
 *
 * Usage: bun scripts/launch-covers.ts <uid | email>
 */

import { mkdir, readdir, rm } from 'node:fs/promises'
import { join } from 'node:path'
import type { Book } from '../server/domain/book/types'

process.env.GOOGLE_CLOUD_PROJECT ??= 'shiori-polyforms'
// Looking a reader up by email goes through Identity Toolkit, which refuses user
// credentials that name no project to bill.
process.env.GOOGLE_CLOUD_QUOTA_PROJECT ??= 'shiori-polyforms'

/** The reader's books that make the cut, by title, with the cover their record
 *  carries. */
const OWN_TITLES = [
  'Dungeon Crawler Carl',
  "L'ogive du jugement dernier",
  'Ravage',
  'La nuit des temps',
  'Hypérion',
  "La chute d'Hypérion",
  'Endymion',
  "L'éveil d'Endymion",
  'Fondation',
  'Fondation et Empire',
  'Seconde Fondation',
  'Prélude à Fondation',
  "L'Aube de Fondation",
  'Fondation foudroyée',
  'Terre et Fondation',
  'Le problème à trois corps',
  'La Forêt sombre',
  'La mort immortelle',
  "L'apprenti assassin",
  "L'assassin du roi",
  'La nef du crépuscule',
  'Le poison de la vengeance',
  'La voie magique',
  'La reine solitaire',
  '1984',
  'Fahrenheit 451',
]

/** The classics, and more Barjavel than the library holds, each pinned to an Open Library cover picked by eye: a search
 *  turns up study guides and blank bindings as readily as a real cover. */
const CLASSICS: { title: string; coverId: number }[] = [
  { title: 'Germinal', coverId: 8236935 },
  { title: "L'Assommoir", coverId: 8243261 },
  { title: 'Au Bonheur des Dames', coverId: 8246183 },
  { title: 'Nana', coverId: 8237804 },
  { title: 'La Bête humaine', coverId: 979860 },
  { title: 'Les Misérables', coverId: 10073294 },
  { title: 'Notre-Dame de Paris', coverId: 11849382 },
  { title: 'Le Comte de Monte-Cristo', coverId: 14560865 },
  { title: 'Madame Bovary', coverId: 12993424 },
  { title: 'Le Père Goriot', coverId: 8237944 },
  { title: 'Le Rouge et le Noir', coverId: 8231413 },
  { title: "L'Étranger", coverId: 13151269 },
  { title: 'La Peste', coverId: 13151272 },
  { title: 'Vingt mille lieues sous les mers', coverId: 6573517 },
  { title: 'Le Tour du monde en quatre-vingts jours', coverId: 6976035 },
  { title: 'La Ferme des animaux', coverId: 11261770 },
  { title: 'Le Meilleur des mondes', coverId: 8231823 },
  { title: 'Le Petit Prince', coverId: 10708272 },
  { title: 'Crime et Châtiment', coverId: 10562435 },
  { title: 'Guerre et Paix', coverId: 12621906 },
  { title: 'La Métamorphose', coverId: 13302999 },
  { title: 'Le Vieil Homme et la Mer', coverId: 967065 },
  { title: 'Des souris et des hommes', coverId: 14589084 },
  { title: 'Orgueil et Préjugés', coverId: 15092533 },
  { title: 'Frankenstein', coverId: 12356249 },
  { title: 'Dracula', coverId: 12216503 },
  { title: 'Dune', coverId: 980253 },
  { title: 'Les Fleurs du mal', coverId: 3124316 },
  { title: 'Cyrano de Bergerac', coverId: 8236320 },
  { title: 'Le Voyageur imprudent', coverId: 7267304 },
  { title: 'Le Grand Secret', coverId: 979477 },
  { title: 'Les Chemins de Katmandou', coverId: 979495 },
  { title: 'Une rose au paradis', coverId: 11735213 },
  { title: 'Tarendol', coverId: 11574864 },
  { title: 'Colomb de la lune', coverId: 967446 },
]

const [, , reader] = process.argv
if (!reader) {
  process.stderr.write('usage: bun scripts/launch-covers.ts <uid | email>\n')
  process.exit(64)
}

/** Twice the height the opening draws a cover at, for a 2× screen and a
 *  3× one that does not mind: the covers move, nobody reads their type. */
const HEIGHT_PX = 300
const target = join(import.meta.dir, '../ios/Shiori/LaunchCovers')

const { db } = await import('~/system/firebase')
const { getAuth } = await import('firebase-admin/auth')

const userId = reader.includes('@') ? (await getAuth().getUserByEmail(reader)).uid : reader

const snapshot = await db().collection('books').where('userId', '==', userId).get()
const books = snapshot.docs.map((doc) => doc.data() as Book)
const own = OWN_TITLES.map((title) => {
  const book = books.find((book) => same(book.title, title) && book.publishedCoverUrl)
  if (!book) process.stdout.write(`not in the library with a cover: ${title}\n`)
  return book && { title, url: String(book.publishedCoverUrl) }
}).filter((cover) => cover !== undefined)
const classics = CLASSICS.map(({ title, coverId }) => ({
  title,
  url: `https://covers.openlibrary.org/b/id/${coverId}-L.jpg`,
}))

await mkdir(target, { recursive: true })
for (const name of await readdir(target))
  if (name.startsWith('launch-cover-')) await rm(join(target, name))

let written = 0
for (const { title, url } of [...own, ...classics]) {
  const response = await fetch(url)
  if (!response.ok) {
    process.stdout.write(`skipped ${response.status}  ${title}\n`)
    continue
  }
  written += 1
  const file = join(target, `launch-cover-${String(written).padStart(2, '0')}.jpg`)
  await Bun.write(`${file}.source`, await response.arrayBuffer())
  // `sips` ships with macOS and re-encodes whatever came back — JPEG, PNG,
  // WebP — as a small JPEG of the height the opening needs.
  const sips = Bun.spawnSync([
    'sips',
    '--resampleHeight',
    String(HEIGHT_PX),
    '-s',
    'format',
    'jpeg',
    '-s',
    'formatOptions',
    '70',
    `${file}.source`,
    '--out',
    file,
  ])
  await rm(`${file}.source`)
  if (sips.exitCode !== 0) {
    written -= 1
    process.stdout.write(`unreadable   ${title}\n`)
    continue
  }
  process.stdout.write(`${String(written).padStart(2, '0')}  ${title}\n`)
}

process.stdout.write(`\n${written} covers in ios/Shiori/LaunchCovers\n`)

/** Titles compared the way a reader would: case and apostrophe style aside. */
function same(a: string, b: string): boolean {
  const plain = (s: string) => s.toLocaleLowerCase('fr').replaceAll('’', "'").trim()
  return plain(a) === plain(b)
}
