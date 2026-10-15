import { z } from 'zod'
import { shelfKeyOf } from '~/domain/book/business-rules'
import { BOOK_LANGUAGES, type BookLanguage } from '~/domain/book/types'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import { SUGGESTION_KINDS, type Suggestion, type SuggestionKind } from './types'

const answerItem = z.object({
  title: z.string().trim().min(1),
  originalTitle: z.string().trim().min(1).optional(),
  author: z.string().trim().min(1),
  language: z.string().trim().optional(),
  kind: z.string().trim().optional(),
  reason: z.string().trim().min(1),
  short: z.string().trim().min(1),
  references: z.array(z.string()).optional(),
})

/** The suggestions in the model's answer: the JSON array it was asked for,
 *  read out of any text around it. An item missing a title, an author or a
 *  reason is left out, the others kept; two items naming the same book keep
 *  the first. An answer with no array at all throws: the prompt is to look at. */
export const suggestionsOf = (answer: string): Suggestion[] => {
  const start = answer.indexOf('[')
  const end = answer.lastIndexOf(']')
  if (start < 0 || end <= start)
    throw new Error(`no JSON array in the answer: ${answer.slice(0, 500)}`)
  const items = z.array(z.unknown()).parse(JSON.parse(answer.slice(start, end + 1)))
  const suggestions: Suggestion[] = []
  for (const item of items) {
    const parsed = answerItem.safeParse(item)
    if (!parsed.success) continue
    const { title, originalTitle, author, language, kind, reason, short, references } = parsed.data
    const authors = author
      .split(/\s*[,&]\s*|\s+et\s+|\s+and\s+/)
      .map((name) => name.trim())
      .filter((name) => name.length > 0)
      .map(AuthorName)
    const original = originalTitle ?? title
    const key = shelfKeyOf(original, authors[0])
    if (suggestions.some((known) => known.key === key)) continue
    suggestions.push({
      key,
      title: BookTitle(title),
      originalTitle: BookTitle(original),
      authors,
      language: languageOf(language),
      kind: kindOf(kind),
      reason,
      short,
      references: (references ?? []).map((reference) => reference.trim()).filter(Boolean),
    })
  }
  return suggestions
}

const languageOf = (code: string | undefined): BookLanguage => {
  const lowered = code?.toLowerCase()
  return BOOK_LANGUAGES.find((language) => language === lowered) ?? 'en'
}

const kindOf = (kind: string | undefined): SuggestionKind =>
  SUGGESTION_KINDS.find((candidate) => candidate === kind?.toLowerCase()) ?? 'novel'
