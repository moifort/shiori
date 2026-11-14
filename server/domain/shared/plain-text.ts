/** A store's summary as text: Audible's arrive as HTML, its public catalogue's
 *  too. Stored as written they would render as `<p>` on the book screen, so the
 *  markup is taken out here rather than in every view that draws a synopsis. */
export const plainTextOf = (html: string | undefined): string | undefined => {
  if (!html) return undefined
  return (
    html
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n\n')
      .replace(/<[^>]*>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;|&apos;/g, "'")
      .replace(/\n{3,}/g, '\n\n')
      .trim()
      // Audible summaries run long; a synopsis is capped at 4000 characters, and a
      // truncated one beats losing it to a failed constructor.
      .slice(0, 4000)
      .trim()
  )
}
