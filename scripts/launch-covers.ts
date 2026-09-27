/**
 * Bundles the covers that drift behind the icon while the app opens: a reader's
 * own books, named by title, and the great classics, from Open Library. The
 * reader's covers are recent editions, bright and drawn, and set the tone: an
 * old binding or a plain type cover sinks into the background.
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
 *  carries. A title shared by two books — an audiobook and its print edition —
 *  takes both. */
const OWN_TITLES = [
  'Dungeon Crawler Carl',
  'Le Portail des dieux infernaux',
  'L’ogive du jugement dernier',
  'La Mascarade du boucher',
  'This Inevitable Ruin',
  'The Gate of the Feral Gods',
  'Operation Bounce House',
  'Red Rising',
  'Red Mars',
  'Métro 2033',
  'Neuromancien',
  'Projet Dernière chance',
  'Le Vaisseau-monde Humilité',
  'Vigilante 211',
  'Lumière',
  'Iron Prince (French Edition)',
  'Tschaï',
  "Chasseur d'épaves 1",
  'Heretical Fishing: A Cozy Guide to Annoying the Cults, Outsmarting the Fish, and Alienating Oneself',
  'Le secret de Sombre-bois',
  'Fourth Wing (French Edition)',
  'Défaillances Systèmes',
  'Nous sommes Légion (nous sommes Bob)',
  "L'Eveil du Léviathan",
  'La Fin de tout',
  'Le Vieil homme et la guerre',
  'Ubik',
  'Shibumi',
  'Les Champs de la Lune',
  'Un océan de rouille',
  "La Légende des Firemane - L'intégrale",
  'Le Déchronologue',
  'Le Seigneur de la Tour',
  "L'Empire caché",
  'Les Guerriers du silence',
  'Le meilleur des mondes',
  'Dune - Livre premier et livre second',
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
  'Ravage',
  'La nuit des temps',
  '1984',
  'Fahrenheit 451',
]

/** The classics, and more Barjavel than the library holds, each pinned to an
 *  Open Library cover picked by eye for a recent, coloured edition: a search
 *  turns up study guides and blank bindings as readily as a real cover. */
const CLASSICS: { title: string; coverId: number }[] = [
  { title: 'Germinal', coverId: 2140542 },
  { title: 'Nana', coverId: 3080747 },
  { title: "L'Assommoir", coverId: 968643 },
  { title: 'La Bête humaine', coverId: 968837 },
  { title: 'Au Bonheur des Dames', coverId: 8246183 },
  { title: 'Notre-Dame de Paris', coverId: 11849382 },
  { title: 'Le Comte de Monte-Cristo', coverId: 14560865 },
  { title: 'La Peste', coverId: 13151272 },
  { title: 'Vingt mille lieues sous les mers', coverId: 3076817 },
  { title: 'La Ferme des animaux', coverId: 11261770 },
  { title: 'Le Petit Prince', coverId: 10708272 },
  { title: 'Crime et Châtiment', coverId: 10562435 },
  { title: 'La Métamorphose', coverId: 13302999 },
  { title: 'Des souris et des hommes', coverId: 14589084 },
  { title: 'Orgueil et Préjugés', coverId: 15092533 },
  { title: 'Frankenstein', coverId: 12356249 },
  { title: 'Dracula', coverId: 12216503 },
  { title: 'Cyrano de Bergerac', coverId: 8236320 },
  { title: 'Le Grand Secret', coverId: 979477 },
  { title: 'Les Chemins de Katmandou', coverId: 979495 },
  { title: 'Une rose au paradis', coverId: 11735213 },
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
const own = OWN_TITLES.flatMap((title) => {
  const found = books.filter((book) => same(book.title, title) && book.publishedCoverUrl)
  if (found.length === 0) process.stdout.write(`not in the library with a cover: ${title}\n`)
  return found.map((book) => ({ title, url: String(book.publishedCoverUrl) }))
})
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
