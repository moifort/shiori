#!/usr/bin/env bun
/**
 * Composes the App Store panels: photographs of hands and phones on the listing's
 * very light grey, with the app's real captures in the phones.
 *
 * The image model draws each scene — a hand, a phone, a book, a bookshelf — with
 * the phone's display in flat chroma-key green and the book's cover in magenta. It
 * is never asked for the app or for a cover, whose text it garbles: those are the
 * real captures (scripts/screenshots.sh) and the real cover, put in the photograph
 * by composite-mockup.swift. finish-panel.swift then fits each photograph to the
 * 6.9" panel, brings its backdrop to the exact grey so panels drawn apart meet
 * without a seam, and sets the caption.
 *
 * Three kinds of panel. The first two are one photograph cut in two: a reader
 * photographing a book, the phone showing its record filled in. The last is two
 * friends' hands, each phone showing the Partagé page. In between, the app alone:
 * an iPhone drawn to its exact proportions (device-panel.swift), on the grey —
 * hands added nothing there.
 *
 * Scenes are cached in screenshots/appstore/scenes/ and committed: changing a
 * caption or a capture asks nothing of the model. Look at a new scene before
 * keeping it — the model sometimes lays a grey patch on the green, which the key
 * takes as screen, and sometimes draws the phone smaller than asked.
 *
 * Usage:
 *   bun scripts/generate-appstore-previews.ts                     # every panel
 *   bun scripts/generate-appstore-previews.ts --regenerate home   # draw one scene again
 *
 * A new scene needs NITRO_GOOGLE_API_KEY in .env.
 */
import { mkdir, mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { $ } from 'bun'

const MODEL = 'gemini-3-pro-image'
const LANGUAGE = 'fr'

const repoRoot = join(import.meta.dir, '..')
const captures = join(repoRoot, 'screenshots/captures', LANGUAGE)
const appstoreDir = join(repoRoot, 'screenshots/appstore')
const sceneDir = join(appstoreDir, 'scenes')
const outputDir = join(appstoreDir, LANGUAGE)
const hyperionCover = join(appstoreDir, 'assets/hyperion-cover.jpg')
const compositeMockup = join(import.meta.dir, 'composite-mockup.swift')
const finishPanel = join(import.meta.dir, 'finish-panel.swift')
const devicePanel = join(import.meta.dir, 'device-panel.swift')

const BACKDROP = `Background: one seamless, perfectly plain, flat, very light neutral grey (#F2F2F4) — no texture, no gradient, no vignette, no horizon line. Soft, even daylight from the upper left.`
const GREEN_SCREEN = `The display has the slim proportions of an iPhone 17 Pro Max: its height is 2.17 times its width. The phone's display is ONE uniform, flat, pure chroma-key green (#00FF00) from edge to edge of the glass, with the black pill-shaped Dynamic Island at the top: no icons, no reflections, no gradient. Fingers must not cover the display.`
const NO_TEXT = `ABSOLUTELY NO TEXT, letters, logos or watermarks anywhere. Natural skin, five fingers, sharp focus.`

/** A scene the model draws, cached under its name. */
type Scene = { name: string; aspect: string; prompt: string }

const SCAN: Scene = {
  name: 'scan',
  aspect: '1:1',
  prompt: `ONE single continuous photorealistic studio photograph, square, one shot from one camera, seen from slightly above. It is NOT a diptych: no dividing line, no border, no seam; every object appears exactly once.
${BACKDROP}
A reader photographs a book with their phone. The frame will be cut down its vertical middle into two side-by-side panels, and the scene must visibly run across that cut:
- A single large closed paperback book lies flat on the light grey surface, ACROSS the vertical centre line: about 60% of it in the left half and 40% in the right half, its front cover facing up. The cover is ONE uniform, flat, pure magenta (#FF00FF) rectangle from edge to edge, no print, no texture (a placeholder to be replaced). The book is large: about 55% of the frame's width.
- In the right half, beside the right end of the book and NOT overlapping it, a single hand (hand and wrist only, light-medium skin) enters from the right edge and holds one modern iPhone almost upright, its screen facing the viewer straight on (turned at most 10° toward the book, as if it has just photographed it). The phone is LARGE — about 62% of the frame's height — and stays entirely in the right half; nothing covers any part of the book's cover.
${GREEN_SCREEN}
The top 18% of the frame is empty background, for captions.
${NO_TEXT}`,
}

const SHARE: Scene = {
  name: 'share',
  aspect: '9:16',
  prompt: `A photorealistic studio photograph for an App Store marketing image, vertical 9:16.
${BACKDROP}
Two friends show each other their phones, seen from above: one hand with dark brown skin enters from the LEFT edge and holds a modern iPhone upside down (rotated 180°, its Dynamic Island toward the bottom) in the upper-left; another hand with light skin enters from the RIGHT edge and holds a modern iPhone upright (Dynamic Island at the top) in the lower-right. Both phones are VERY LARGE — each about 52% of the frame's height and 58% of its width — overlapping diagonally a little at their inner corners is fine, but their displays never touch. Both displays face the viewer. Only hands and wrists, no faces; no arm reaches the top of the frame.
The topmost 15% of the frame is empty background for a caption: nothing enters it.
Each display has the slim proportions of an iPhone 17 Pro Max, its height 2.17 times its width. Each phone's display is ONE uniform, flat, pure chroma-key green (#00FF00) from edge to edge of the glass, with the black pill-shaped Dynamic Island: no icons, no reflections, no gradient. Fingers must not cover the displays.
${NO_TEXT}`,
}

/** The app alone, in a drawn iPhone on the grey. */
type DevicePanel = {
  kind: 'device'
  output: string
  capture: string
  caption: string
}

const LIGHT_GREY = '#F2F2F4'

const DEVICES: DevicePanel[] = [
  {
    kind: 'device',
    output: '03-bibliotheque.png',
    capture: '01-library.png',
    caption: 'Livres et audio !',
  },
  {
    kind: 'device',
    output: '04-statistiques.png',
    capture: '02-stats.png',
    caption: 'Des analytics détaillés',
  },
  {
    kind: 'device',
    output: '05-series.png',
    capture: '03-series.png',
    caption: 'Suivi de vos séries préférées',
  },
  {
    kind: 'device',
    output: '06-serie.png',
    capture: '04-saga.png',
    caption: 'Être averti des sorties et disponibilités',
  },
  {
    kind: 'device',
    output: '07-decouvrir.png',
    capture: '05-discover.png',
    caption: 'Découvrez vos nouveaux coups de cœur',
  },
]

const generateScene = async (scene: Scene, target: string) => {
  const apiKey = process.env.NITRO_GOOGLE_API_KEY
  if (!apiKey) throw new Error('NITRO_GOOGLE_API_KEY is not set (expected in .env)')
  console.log(`${scene.name}: drawing a new scene with ${MODEL}...`)
  // A 2K image takes a minute to come back, and the connection is sometimes
  // reset under it: tried three times before giving up.
  const request = () =>
    fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
      method: 'POST',
      headers: { 'x-goog-api-key': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: scene.prompt }] }],
        generationConfig: {
          responseModalities: ['TEXT', 'IMAGE'],
          imageConfig: { aspectRatio: scene.aspect, imageSize: '2K' },
        },
      }),
    })
  let response: Response | undefined
  for (let attempt = 1; !response; attempt += 1) {
    try {
      response = await request()
    } catch (error) {
      if (attempt >= 3) throw error
      console.log(`${scene.name}: ${String(error)}, trying again`)
    }
  }
  if (!response.ok) throw new Error(`Gemini API error ${response.status}: ${await response.text()}`)
  const result = (await response.json()) as {
    candidates?: { content?: { parts?: { inlineData?: { data: string } }[] } }[]
  }
  const image = result.candidates?.[0]?.content?.parts?.find((part) => part.inlineData)?.inlineData
  if (!image) throw new Error(`No image in response: ${JSON.stringify(result).slice(0, 2000)}`)
  const png = `${target}.png`
  await Bun.write(png, Buffer.from(image.data, 'base64'))
  // Committed as JPEG: a PNG weighs four times as much, for a scene the panel resizes anyway.
  await $`sips -s format jpeg -s formatOptions 90 ${png} --out ${target}`.quiet()
  await $`rm ${png}`.quiet()
}

const argv = process.argv.slice(2)
const regenerate = argv.includes('--regenerate')
  ? argv[argv.indexOf('--regenerate') + 1]
  : undefined

await mkdir(sceneDir, { recursive: true })
await mkdir(outputDir, { recursive: true })
const work = await mkdtemp(join(tmpdir(), 'shiori-panels-'))

/** The scene's cached image, drawn first when it is missing or asked for again. */
const sceneImage = async (scene: Scene) => {
  const path = join(sceneDir, `${scene.name}.jpg`)
  if (regenerate === scene.name || !(await Bun.file(path).exists()))
    await generateScene(scene, path)
  return path
}

const capture = async (name: string) => {
  const path = join(captures, name.replace('@180', ''))
  if (!(await Bun.file(path).exists()))
    throw new Error(`Missing capture: ${path} — run scripts/screenshots.sh`)
  return join(captures, name)
}

const caption = async (input: string, output: string, text: string) => {
  await $`swift ${finishPanel} caption ${input} ${join(outputDir, output)} ${text}`.quiet()
  console.log(`  ${join(outputDir, output)}`)
}

// 01 and 02: one photograph, cut in two.
{
  const fitted = join(work, 'scan-fit.png')
  const covered = join(work, 'scan-cover.png')
  const screened = join(work, 'scan-screen.png')
  await $`swift ${finishPanel} fit ${await sceneImage(SCAN)} ${fitted} --backdrop --width 2640`.quiet()
  await $`swift ${compositeMockup} ${fitted} ${covered} ${hyperionCover}`
    .env({ ...process.env, KEY: 'magenta' })
    .quiet()
  await $`swift ${compositeMockup} ${covered} ${screened} ${await capture('00-scan.png')}`.quiet()
  const halves = [
    { output: '01-scan-livre.png', text: 'Scannez…', offset: 0 },
    { output: '02-scan-fiche.png', text: '…Shiori fait le reste', offset: 1320 },
  ]
  for (const half of halves) {
    const cut = join(work, `scan-${half.offset}.png`)
    await $`cp ${screened} ${cut}`.quiet()
    // offsetY is 1, not 0: sips ignores an all-zero --cropOffset and centres the crop.
    await $`sips -c 2868 1320 --cropOffset 1 ${half.offset} ${cut}`.quiet()
    await caption(cut, half.output, half.text)
  }
}

// 03 to 07: the app alone.
for (const panel of DEVICES) {
  const drawn = join(work, panel.output)
  await $`swift ${devicePanel} ${LIGHT_GREY} ${await capture(panel.capture)} ${drawn}`.quiet()
  await caption(drawn, panel.output, panel.caption)
}

// 08: two friends, the same page on both phones.
{
  const fitted = join(work, 'share-fit.png')
  const screened = join(work, 'share-screens.png')
  await $`swift ${finishPanel} fit ${await sceneImage(SHARE)} ${fitted} --backdrop --zoom 1.0 --center 0.49`.quiet()
  const shared = await capture('06-shared.png')
  await $`swift ${compositeMockup} ${fitted} ${screened} ${`${shared}@180`} ${shared}`.quiet()
  await caption(screened, '08-partage.png', 'Partagez votre bibliothèque avec vos proches')
}
console.log('Done.')
