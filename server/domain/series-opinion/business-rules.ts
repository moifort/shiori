import type { BookLanguage } from '~/domain/book/types'
import type { SeriesOpinion } from '~/domain/series-opinion/types'

type Following = Pick<SeriesOpinion, 'unfollowed' | 'unfollowedLanguages'>

/** Whether the reader set aside the edition of a saga held in `language`. A
 *  saga set aside as a whole sets aside every edition; otherwise only the
 *  languages named are, and the edition that names no language never is. */
export const editionUnfollowed = (
  opinion: Following | null | undefined,
  language: BookLanguage | undefined,
): boolean =>
  opinion?.unfollowed === true ||
  (language !== undefined && (opinion?.unfollowedLanguages ?? []).includes(language))

/** Where following stands once the reader follows or sets aside a saga.
 *
 *  Named by its language, one edition moves and the others stay where the
 *  reader put them: two editions are two sets of books. Without a language —
 *  the dashboard card, which draws every edition as one — the whole saga
 *  moves. Following one edition of a saga set aside as a whole leaves the
 *  other editions the reader holds aside, which `heldLanguages` names. */
export const followingAfter = (
  opinion: Following,
  followed: boolean,
  language: BookLanguage | undefined,
  heldLanguages: readonly BookLanguage[],
): Following => {
  if (language === undefined)
    return { unfollowed: followed ? undefined : true, unfollowedLanguages: undefined }
  const aside = new Set(opinion.unfollowed ? heldLanguages : (opinion.unfollowedLanguages ?? []))
  if (followed) aside.delete(language)
  else aside.add(language)
  return { unfollowed: undefined, unfollowedLanguages: aside.size > 0 ? [...aside] : undefined }
}
