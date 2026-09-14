import { parseChangelog } from '~/domain/changelog/business-rules'
import type { Language } from '~/domain/shared/language'
import { changelogMarkdownByLanguage } from '~/system/changelog-content'

export namespace ChangelogQuery {
  // Served in the caller's language, falling back to English then French for a
  // language whose changelog asset is missing.
  export const list = async (language: Language) =>
    parseChangelog(
      changelogMarkdownByLanguage[language] ??
        changelogMarkdownByLanguage.en ??
        changelogMarkdownByLanguage.fr ??
        '',
    )
}
