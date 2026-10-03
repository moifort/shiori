#!/usr/bin/env bun
/**
 * Composes the App Store panels: photographs of hands and phones on the listing's
 * cream, with the app's real captures in the phones.
 *
 * The image model draws each scene — a hand, a phone, a book, a bookshelf — with
 * the phone's display in flat chroma-key green and the book's cover in magenta. It
 * is never asked for the app or for a cover, whose text it garbles: those are the
 * real captures (scripts/screenshots.sh) and the real cover, put in the photograph
 * by composite-mockup.swift. finish-panel.swift then fits each photograph to the
 * 6.9" panel, brings its backdrop to the exact cream so panels drawn apart meet
 * without a seam, and sets the caption.
 *
 * The first two panels are one moment told in two: the book, then the phone that
 * photographed it, its record filled in.
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

const CREAM = `Background: one seamless, perfectly plain, flat warm cream colour (#F3ECDC) — no texture, no gradient, no vignette, no horizon line. Soft, even daylight from the upper left.`
const GREEN_SCREEN = `The phone's display is ONE uniform, flat, pure chroma-key green (#00FF00) from edge to edge of the glass, with the black pill-shaped Dynamic Island at the top: no icons, no reflections, no gradient. Fingers must not cover the display.`
const NO_TEXT = `ABSOLUTELY NO TEXT, letters, logos or watermarks anywhere. Natural skin, five fingers, sharp focus.`

/** A phone held up close on the cream, by a hand described in a few words. */
const handHeld = (
  hand: string,
) => `A photorealistic studio EXTREME CLOSE-UP photograph, vertical 9:16.
${CREAM}
Subject: one modern iPhone with thin titanium edges, upright, screen facing the viewer, held by ${hand} whose fingers wrap its lower left and right edges. The phone is HUGE in the frame: its top edge sits at 17% of the image height and its bottom edge at 96% of the image height; it spans 86% of the image width. Only a little of the hand shows, around the lower part of the phone and below it. Nothing else in the frame.
${GREEN_SCREEN}
The top 15% of the frame is empty cream background.
${NO_TEXT}`

type Panel = {
  output: string
  scene: string
  prompt: string
  /** The backdrop is the listing's cream, to be evened out to it. */
  cream: boolean
  /** Where the panel's middle falls across the scene, when its subject is off centre. */
  center?: number
  /** The book's magenta cover, replaced by the real one. */
  cover?: string
  /** The captures for the green screens, top to bottom; `@180` on a phone held upside down. */
  screens: string[]
  caption: string
}

const PANELS: Panel[] = [
  {
    output: '01-scan-livre.png',
    scene: 'scan-book',
    cream: true,
    cover: hyperionCover,
    screens: [],
    caption: 'Photographiez la couverture',
    prompt: `A photorealistic studio photograph, vertical 9:16.
${CREAM}
Subject: a single closed paperback book standing almost upright, leaning slightly back, its front cover facing the viewer, seen straight on, LARGE: it fills about 80% of the frame's width and about 55% of its height, centred horizontally, in the lower 70% of the frame. Its front cover is ONE uniform, flat, pure magenta (#FF00FF) rectangle from edge to edge, no print, no texture, no reflection (a placeholder that will be replaced).
The top 25% of the frame is empty cream background.
ABSOLUTELY NO TEXT, letters, logos or watermarks anywhere.`,
  },
  {
    output: '02-scan-fiche.png',
    scene: 'scan-phone',
    cream: true,
    screens: ['00-scan.png'],
    caption: 'Shiori remplit la fiche',
    prompt: handHeld('a single hand (light-medium skin)'),
  },
  {
    output: '03-bibliotheque.png',
    scene: 'library',
    cream: false,
    screens: ['01-library.png'],
    caption: 'Une photo, votre bibliothèque',
    prompt: `A photorealistic photograph for an App Store marketing image, vertical 9:16.
The WHOLE background, from the top edge to the bottom edge and from side to side, is a wall of wooden bookshelves packed with colourful books, softly out of focus — no bare wall, no ceiling, no floor, no window: books everywhere behind the phone. The library is darker and moodier: dark walnut shelves, deep shadows between the books, dim warm lamplight, so the bright phone stands out.
A person's hand (only the hand and wrist, medium-dark skin) holds a modern iPhone upright, facing the camera straight on, IN A CLOSE-UP, very large and close to the camera: the phone fills 78% of the image height and 70% of its width, centred horizontally, its top edge 17% below the top of the image, its bottom edge at 95% of the image height. The phone is the dominant subject, far larger than in an ordinary photograph.
${GREEN_SCREEN}
${NO_TEXT}`,
  },
  {
    output: '04-accueil.png',
    scene: 'home',
    cream: true,
    screens: ['02-home.png'],
    caption: 'Des analytics détaillés',
    prompt: handHeld('a left hand with deep brown skin'),
  },
  {
    output: '05-series.png',
    scene: 'series',
    cream: true,
    screens: ['03-series.png'],
    caption: "Détection des séries et de votre état d'avancement",
    prompt: handHeld('a right hand with light, freckled skin'),
  },
  {
    output: '06-serie.png',
    scene: 'saga',
    cream: true,
    screens: ['04-saga.png'],
    caption: "Être averti de l'arrivée d'un tome de votre série préférée",
    prompt: handHeld('a left hand with olive, medium skin and a thin silver ring'),
  },
  {
    output: '07-decouvrir.png',
    scene: 'discover',
    cream: true,
    screens: ['05-discover.png'],
    caption: 'Découvrez les sorties, les disponibilités et les coups de cœur de vos amis',
    prompt: handHeld('a right hand with light-medium East Asian skin'),
  },
  {
    output: '08-partage.png',
    scene: 'share',
    cream: true,
    center: 0.54,
    // The friend across the table holds their phone upside down: their library.
    screens: ['01-library.png@180', '06-shared.png'],
    caption: 'Partagez votre bibliothèque avec vos proches',
    prompt: `A photorealistic studio photograph for an App Store marketing image, vertical 9:16.
${CREAM}
Two friends sitting face to face show each other their phones, seen from above: one hand with dark brown skin enters from the TOP edge and holds a modern iPhone upside down (rotated 180°, its Dynamic Island toward the bottom), in the upper part of the frame, shifted slightly to the left; another hand with light skin enters from the BOTTOM edge and holds a modern iPhone upright (Dynamic Island at the top), in the lower part, shifted slightly to the right. Both phones are LARGE — each about 42% of the frame's height — both displays face the viewer, and they do not overlap. Both phones stay entirely within the central 78% of the frame's width: the left and right 11% hold nothing but backdrop and wrists, since the image is narrowed on both sides afterwards. Only hands and wrists, no faces.
The topmost 14% of the frame is empty cream background for a caption: the upper phone starts below it.
Each phone's display is ONE uniform, flat, pure chroma-key green (#00FF00) from edge to edge of the glass, with the black pill-shaped Dynamic Island: no icons, no reflections, no gradient. Fingers must not cover the displays.
${NO_TEXT}`,
  },
]

const generateScene = async (panel: Panel, target: string) => {
  const apiKey = process.env.NITRO_GOOGLE_API_KEY
  if (!apiKey) throw new Error('NITRO_GOOGLE_API_KEY is not set (expected in .env)')
  console.log(`${panel.scene}: drawing a new scene with ${MODEL}...`)
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: 'POST',
      headers: { 'x-goog-api-key': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: panel.prompt }] }],
        generationConfig: {
          responseModalities: ['TEXT', 'IMAGE'],
          imageConfig: { aspectRatio: '9:16', imageSize: '4K' },
        },
      }),
    },
  )
  if (!response.ok) throw new Error(`Gemini API error ${response.status}: ${await response.text()}`)
  const result = (await response.json()) as {
    candidates?: { content?: { parts?: { inlineData?: { data: string } }[] } }[]
  }
  const image = result.candidates?.[0]?.content?.parts?.find((part) => part.inlineData)?.inlineData
  if (!image) throw new Error(`No image in response: ${JSON.stringify(result).slice(0, 2000)}`)
  const png = `${target}.png`
  await Bun.write(png, Buffer.from(image.data, 'base64'))
  // Committed as JPEG: a 4K PNG weighs four times as much, for a scene the panel shrinks.
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

for (const panel of PANELS) {
  const scene = join(sceneDir, `${panel.scene}.jpg`)
  if (regenerate === panel.scene || !(await Bun.file(scene).exists()))
    await generateScene(panel, scene)
  for (const screen of panel.screens) {
    const capture = join(captures, screen.replace('@180', ''))
    if (!(await Bun.file(capture).exists()))
      throw new Error(`Missing capture: ${capture} — run scripts/screenshots.sh`)
  }

  let current = join(work, `${panel.scene}-fit.png`)
  const fit = [
    ...(panel.cream ? ['--cream'] : []),
    ...(panel.center ? ['--center', String(panel.center)] : []),
  ]
  await $`swift ${finishPanel} fit ${scene} ${current} ${fit}`.quiet()
  if (panel.cover) {
    const next = join(work, `${panel.scene}-cover.png`)
    await $`swift ${compositeMockup} ${current} ${next} ${panel.cover}`
      .env({ ...process.env, KEY: 'magenta' })
      .quiet()
    current = next
  }
  if (panel.screens.length > 0) {
    const next = join(work, `${panel.scene}-screens.png`)
    const screens = panel.screens.map((screen) => join(captures, screen))
    await $`swift ${compositeMockup} ${current} ${next} ${screens}`.quiet()
    current = next
  }
  const output = join(outputDir, panel.output)
  await $`swift ${finishPanel} caption ${current} ${output} ${panel.caption}`.quiet()
  console.log(`  ${output}`)
}
console.log('Done.')
