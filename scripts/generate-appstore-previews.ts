#!/usr/bin/env bun
/**
 * Composes the App Store panels from the app's captures, transposed from Vinarium.
 *
 * Each panorama is ONE continuous image: the image model renders an empty room,
 * then composite-panorama.swift draws a device per panel, pastes the real
 * captures into them and sets the caption above each. The panorama is finally
 * sliced into 1320x2868 portrait panels (the 6.9" size App Store Connect asks
 * for) so the background flows from one App Store screenshot to the next.
 *
 * The model is given the room and nothing else. It garbles any text it draws,
 * so the captions are set in Core Text; and asked for a phone at a given size it
 * returns a different one on every run, so the devices are placed by hand. What
 * is left — light, wood, paper, depth — is what it is good at. One scene per
 * triptych, cached and committed, so a caption changes without an API key.
 *
 * Usage:
 *   bun scripts/generate-appstore-previews.ts                # both panoramas
 *   bun scripts/generate-appstore-previews.ts 1              # one panorama
 *   bun scripts/generate-appstore-previews.ts --regenerate   # new scenes (costs API calls)
 *
 * Reads screenshots/captures/<lang>/ (scripts/screenshots.sh) and writes
 * screenshots/appstore/<lang>/. A new scene needs NITRO_GOOGLE_API_KEY in .env.
 */
import { mkdir, mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { $ } from 'bun'

const MODEL = 'gemini-3-pro-image'
// The 6.9" App Store size, which is the iPhone 17 Pro Max's own screen: the
// captures come from that simulator, so nothing is ever rescaled.
const PANEL_WIDTH = 1320
const PANEL_HEIGHT = 2868
const SCENE_WIDTH = PANEL_WIDTH * 3

const repoRoot = join(import.meta.dir, '..')
const capturesDir = join(repoRoot, 'screenshots/captures')
const appstoreDir = join(repoRoot, 'screenshots/appstore')
// Committed, not temporary: a scene costs an API call, and changing a caption
// must not need an API key — only the compositor.
const sceneCacheDir = join(appstoreDir, 'scenes')
const compositor = join(import.meta.dir, 'composite-panorama.swift')

/** The App Store languages the listing is written in. French alone until the
 *  app has a string catalogue. */
const LANGUAGES = ['fr'] as const
type Language = (typeof LANGUAGES)[number]

type Panel = { source: string; output: string; captions: Record<Language, string> }
type Panorama = {
  id: number
  scene: string
  /** Under every title of the panorama: what the app is for, while each title
   *  says what its panel shows. A visitor may start on any panel. */
  subtitles?: Record<Language, string>
  /** Two or three, the width a scene can be cut into. */
  panels: Panel[]
}

const WHAT_THE_APP_DOES: Record<Language, string> = {
  fr: 'Ce que vous lisez, ce que vous avez lu, ce qui arrive.',
}

const PANORAMAS: Panorama[] = [
  {
    id: 1,
    scene:
      'a warm home library at dusk: floor-to-ceiling wooden bookshelves filled with colourful ' +
      'book spines, a brass reading lamp casting amber light, cream walls, soft depth of field',
    subtitles: WHAT_THE_APP_DOES,
    panels: [
      {
        source: '01-library.png',
        output: '01-bibliotheque.png',
        captions: { fr: 'Une photo, votre bibliothèque' },
      },
      {
        source: '02-home.png',
        output: '02-accueil.png',
        captions: { fr: 'Des analytics détaillés' },
      },
      {
        source: '03-series.png',
        output: '03-series.png',
        captions: { fr: "Détection des séries et de votre état d'avancement" },
      },
    ],
  },
  {
    id: 2,
    scene:
      'a cosy reading corner by a tall window: a deep armchair, stacks of books on a wooden ' +
      'side table, a knitted throw, a cup of tea, late-afternoon golden light, cream and ' +
      'warm red tones',
    subtitles: WHAT_THE_APP_DOES,
    panels: [
      {
        source: '04-saga.png',
        output: '04-serie.png',
        captions: { fr: "Être averti de l'arrivée d'un tome de votre série préférée" },
      },
      {
        source: '05-discover.png',
        output: '05-decouvrir.png',
        captions: {
          fr: 'Découvrez les sorties, les disponibilités et les coups de cœur de vos amis',
        },
      },
      {
        source: '06-shared.png',
        output: '06-partage.png',
        captions: { fr: 'Partagez votre bibliothèque avec vos proches' },
      },
    ],
  },
]

const buildPrompt = (panorama: Panorama) =>
  `You are designing App Store marketing screenshots for "Shiori", a French iOS app that catalogues a reader's books, comics and manga from a photo of their cover.

Create ONE single seamless panoramic marketing image (4:3 landscape). It will be sliced vertically into THREE equal portrait panels (left, center, right) shown side by side on the App Store, so:

- The background is one continuous scene flowing across the whole image with no visible seams: ${panorama.scene}.
- The scene FILLS THE ENTIRE FRAME, edge to edge and corner to corner, like a single photograph taken in one place. No borders, no letterboxing, no horizontal bands, no flat colour blocks, no blurred strip along the top or the bottom, no vignette, no visible boundary between an upper and a lower area — any straight horizontal edge across the image is a defect, and so is a band of blur that does not belong to the depth of the scene.
- Sharpness is even across the whole height: the top of the image is as much part of the room as the middle, only further away. Do not darken, fade or defocus any area to leave room for text.
- NO phone, no device, no screen, no tablet, no e-reader, no object shaped like one anywhere in the image. The devices are drawn afterwards by the compositor, at an exact size and position.
- The middle of each third is where a device will stand, covering roughly 80% of the height: keep those three areas free of anything the eye would miss — no lamp, no cup, no open book centered in a third. Interest belongs at the sides.
- ABSOLUTELY NO TEXT anywhere in the image: no captions, no labels, no logos, no watermarks, no lettering of any kind, and no readable titles on the book spines. Every word is added later.
- CRITICAL composition rule: the image will be cut along two vertical lines at exactly 1/3 and 2/3 of the width. Nothing that reads as a single object may straddle those lines: the scene crosses them, an armchair standing on one does not. Those lines are where the image will be cut, never something to draw: no vertical rule, guide or seam marks them.
- Palette: warm cream paper (#F3ECDC), bookmark red (#C83A46), honeyed wood and amber light; calm, literary, inviting.`

// Only needed to draw a new scene. Composing onto a cached one asks nothing of
// the network, which is the common case.
const apiKey = process.env.NITRO_GOOGLE_API_KEY

const generateScene = async (panorama: Panorama, target: string) => {
  if (!apiKey) throw new Error('NITRO_GOOGLE_API_KEY is not set (expected in .env)')
  console.log(`Panorama ${panorama.id}: generating the scene with ${MODEL}...`)
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: 'POST',
      headers: { 'x-goog-api-key': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: buildPrompt(panorama) }] }],
        generationConfig: {
          responseModalities: ['TEXT', 'IMAGE'],
          imageConfig: { aspectRatio: '4:3', imageSize: '4K' },
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
  await Bun.write(target, Buffer.from(image.data, 'base64'))
}

// The scene at exactly 3960x2868, so the captures are composited at their final
// resolution before the panorama is cut into columns.
const normalize = async (path: string) => {
  await $`sips --resampleWidth ${SCENE_WIDTH} ${path}`.quiet()
  // A model that ignored the 4:3 ratio leaves the resampled height short, and the
  // crop below would then pad with background instead of cropping.
  const size = await $`sips -g pixelHeight ${path}`.text()
  const height = Number(size.match(/pixelHeight: (\d+)/)?.[1])
  if (!(height >= PANEL_HEIGHT))
    throw new Error(
      `Scene is only ${SCENE_WIDTH}x${height} after resampling, needs ${PANEL_HEIGHT} of height`,
    )
  await $`sips -c ${PANEL_HEIGHT} ${SCENE_WIDTH} ${path}`.quiet()
}

/** The generated scene, from the cache when it is there. */
const sceneFor = async (panorama: Panorama, regenerate: boolean) => {
  const cached = join(sceneCacheDir, `scene-${panorama.id}.png`)
  if (!regenerate && (await Bun.file(cached).exists())) {
    console.log(`Panorama ${panorama.id}: reusing the cached scene`)
    return cached
  }
  await generateScene(panorama, cached)
  await normalize(cached)
  return cached
}

const renderLanguage = async (
  panorama: Panorama,
  scene: string,
  language: Language,
  workDir: string,
) => {
  const sources = panorama.panels.map((panel) => join(capturesDir, language, panel.source))
  for (const source of sources)
    if (!(await Bun.file(source).exists()))
      throw new Error(`Missing capture: ${source} — run scripts/screenshots.sh`)

  const width = PANEL_WIDTH * panorama.panels.length
  const canvas = join(workDir, `panorama-${panorama.id}-${language}.png`)
  await $`cp ${scene} ${canvas}`.quiet()
  // A panorama narrower than the scene keeps its left panels: the devices are
  // centred on the canvas's columns, so it is cut to width before they are drawn.
  if (width < SCENE_WIDTH)
    await $`sips -c ${PANEL_HEIGHT} ${width} --cropOffset 1 0 ${canvas}`.quiet()
  const subtitle = panorama.subtitles?.[language] ?? ''
  const pairs = panorama.panels.flatMap((panel, index) => [
    sources[index],
    panel.captions[language],
  ])
  await $`swift ${compositor} ${canvas} ${language} ${subtitle} ${pairs}`.quiet()

  const outputDir = join(appstoreDir, language)
  await mkdir(outputDir, { recursive: true })
  for (const [index, panel] of panorama.panels.entries()) {
    const panelPath = join(outputDir, panel.output)
    await $`cp ${canvas} ${panelPath}`.quiet()
    // offsetY is 1, not 0: sips ignores an all-zero --cropOffset and falls back to a
    // centred crop; 1 is clamped back to the top edge since the crop is full height.
    await $`sips -c ${PANEL_HEIGHT} ${PANEL_WIDTH} --cropOffset 1 ${index * PANEL_WIDTH} ${panelPath}`.quiet()
    console.log(`  ${panelPath}`)
  }
}

const argv = process.argv.slice(2)
const regenerate = argv.includes('--regenerate')
const requested = argv.find((argument) => /^[12]$/.test(argument))
const panoramas = requested ? PANORAMAS.filter((p) => p.id === Number(requested)) : PANORAMAS

await mkdir(sceneCacheDir, { recursive: true })
const workDir = await mkdtemp(join(tmpdir(), 'shiori-previews-'))
for (const panorama of panoramas) {
  const scene = await sceneFor(panorama, regenerate)
  for (const language of LANGUAGES) {
    console.log(`Panorama ${panorama.id}, ${language}:`)
    await renderLanguage(panorama, scene, language, workDir)
  }
}
console.log('Done.')
