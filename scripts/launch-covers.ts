/**
 * Bundles a reader's favourite covers into the iOS app, for the covers that drift
 * behind the icon while the app opens. Reads the reader's favourites from
 * production Firestore, downloads each publisher's cover, shrinks it to the size
 * the opening draws, and writes it to `ios/Shiori/LaunchCovers/`, replacing
 * whatever was there. The app picks up every `launch-cover-*.jpg` it ships with.
 *
 * Only published covers are taken, never a reader's photo: whatever lands in the
 * folder ships to everyone who installs the app, and a photo shows a hand, a
 * table, a room.
 *
 * Runs from the Mac with the gcloud application default credentials
 * (`gcloud auth application-default login`). The reader is named by uid or by
 * the email of their account.
 *
 * Usage: bun scripts/launch-covers.ts <uid | email> [--limit 36]
 */

import { mkdir, readdir, rm } from 'node:fs/promises'
import { join } from 'node:path'
import type { Book } from '../server/domain/book/types'

process.env.GOOGLE_CLOUD_PROJECT ??= 'shiori-polyforms'

const [, , reader] = process.argv
const limitFlag = process.argv.indexOf('--limit')
const limit = limitFlag > 0 ? Number(process.argv[limitFlag + 1]) : 36
if (!reader || !Number.isInteger(limit) || limit < 1) {
  process.stderr.write('usage: bun scripts/launch-covers.ts <uid | email> [--limit 36]\n')
  process.exit(64)
}

/** Twice the height the opening draws a cover at, for a 2× screen and a
 *  3× one that does not mind: the covers move, nobody reads their type. */
const HEIGHT_PX = 300
const target = join(import.meta.dir, '../ios/Shiori/LaunchCovers')

const { db } = await import('~/system/firebase')
const { getAuth } = await import('firebase-admin/auth')

const userId = reader.includes('@') ? (await getAuth().getUserByEmail(reader)).uid : reader

const snapshot = await db()
  .collection('books')
  .where('userId', '==', userId)
  .where('favorite', '==', true)
  .get()
const favourites = snapshot.docs
  .map((doc) => doc.data() as Book)
  .filter((book) => book.publishedCoverUrl)
  // The latest hearts first, so a limit keeps what the reader loves now.
  .sort((a, b) => time(b.favoritedAt) - time(a.favoritedAt))
  .slice(0, limit)

process.stdout.write(
  `${snapshot.size} favourites, ${favourites.length} with a published cover taken\n\n`,
)

await mkdir(target, { recursive: true })
for (const name of await readdir(target))
  if (name.startsWith('launch-cover-')) await rm(join(target, name))

let written = 0
for (const book of favourites) {
  const response = await fetch(String(book.publishedCoverUrl))
  if (!response.ok) {
    process.stdout.write(`skipped ${response.status}  ${book.title}\n`)
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
    process.stdout.write(`unreadable   ${book.title}\n`)
    continue
  }
  process.stdout.write(`${String(written).padStart(2, '0')}  ${book.title}\n`)
}

process.stdout.write(`\n${written} covers in ios/Shiori/LaunchCovers\n`)

function time(date: unknown): number {
  if (date instanceof Date) return date.getTime()
  // Firestore hands a Timestamp back, not a Date.
  if (date && typeof (date as { toMillis?: unknown }).toMillis === 'function')
    return (date as { toMillis: () => number }).toMillis()
  return 0
}
