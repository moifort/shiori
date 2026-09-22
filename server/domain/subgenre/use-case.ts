import { Subgenre } from '~/domain/book/primitives'
import type { LocalizedSubgenre, Subgenre as SubgenreValue } from '~/domain/book/types'
import { generate } from '~/domain/scan/gemini'
import type { Language } from '~/domain/shared/language'
import { translationKeyOf, untranslated } from '~/domain/subgenre/business-rules'
import { SubgenreCommand } from '~/domain/subgenre/command'
import {
  TRANSLATION_SCHEMA,
  type TranslationOutput,
  translationPrompt,
} from '~/domain/subgenre/prompts'
import { SubgenreQuery } from '~/domain/subgenre/query'
import { createLogger } from '~/system/logger'
import { optionally as optional } from '~/utils/input'

const logger = createLogger('subgenre')

export namespace SubgenreUseCase {
  /** The labels a reader typed in `language`, each with its twin in every other
   *  language: from the shared dictionary when anybody met them before, from
   *  one model call for the rest, which the dictionary then keeps.
   *
   *  Never throws: a failed translation must not fail the write that asked for
   *  it. The label then reads the same in every language, and is not filed, so
   *  the next write that meets it tries again. */
  export const localized = async (
    labels: readonly SubgenreValue[],
    language: Language,
  ): Promise<LocalizedSubgenre[]> => {
    if (labels.length === 0) return []
    const known = await SubgenreQuery.known(labels, language)
    const missing = labels.filter((label) => !known.has(translationKeyOf(label, language)))
    const translated = await translatedAndFiled(missing, language)
    return labels.map(
      (label) =>
        known.get(translationKeyOf(label, language)) ??
        translated.get(translationKeyOf(label, language)) ??
        untranslated(label),
    )
  }

  /** Translates labels whose language is not known — the migration's case —
   *  and files them. Throws when the model fails, so the caller decides. */
  export const translateUnknown = async (
    labels: readonly SubgenreValue[],
  ): Promise<LocalizedSubgenre[]> => {
    const pairs = await pairsFor(labels)
    await SubgenreCommand.remember(
      pairs.filter((pair): pair is LocalizedSubgenre => pair !== undefined),
    )
    return labels.map((label, index) => pairs[index] ?? untranslated(label))
  }
}

/** Asks the model for the missing labels, keeps the reader's own spelling on
 *  their side, and files what it got. Keyed by `translationKeyOf` in `language`. */
const translatedAndFiled = async (
  labels: readonly SubgenreValue[],
  language: Language,
): Promise<Map<string, LocalizedSubgenre>> => {
  if (labels.length === 0) return new Map()
  try {
    const pairs = await pairsFor(labels)
    const kept = labels.flatMap((label, index) => {
      const pair = pairs[index]
      return pair ? [[label, { ...pair, [language]: label }] as const] : []
    })
    await SubgenreCommand.remember(kept.map(([, pair]) => pair))
    return new Map(kept.map(([label, pair]) => [translationKeyOf(label, language), pair]))
  } catch (error) {
    logger.warn(`translation failed for ${labels.join(', ')}: ${error}`)
    return new Map()
  }
}

/** One model call; an answer that does not line up with the question, or a
 *  side that is not a valid label, leaves that label untranslated. */
const pairsFor = async (
  labels: readonly SubgenreValue[],
): Promise<(LocalizedSubgenre | undefined)[]> => {
  if (labels.length === 0) return []
  const { value } = await generate<TranslationOutput>({
    step: 'subgenre-translation',
    parts: [{ text: translationPrompt(labels) }],
    responseSchema: TRANSLATION_SCHEMA,
  })
  const answers = value.subgenres ?? []
  if (answers.length !== labels.length) {
    logger.warn(`translation answered ${answers.length} labels for ${labels.length}`)
    return labels.map(() => undefined)
  }
  return answers.map((answer) => {
    const fr = optional(answer.fr, Subgenre)
    const en = optional(answer.en, Subgenre)
    return fr && en ? { fr, en } : undefined
  })
}
