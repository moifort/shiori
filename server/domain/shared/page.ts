/** A page cut from a list already in memory, by the cursor of the row before
 *  it or, for the builds that still send one, by an offset.
 *
 *  The cursor names a row rather than counting rows: a row added or removed
 *  between two pages shifts an offset, showing a row twice or skipping one,
 *  while the row named stays where it is. A cursor naming a row no longer
 *  there restarts from the top, as the library's does. `endCursor` is the
 *  page's last row, for the next page to start after; null on an empty page. */
export const pageAfter = <Row>(
  rows: readonly Row[],
  page: { limit: number; after?: string; offset?: number },
  cursorOf: (row: Row) => string,
): { items: Row[]; hasMore: boolean; endCursor: string | null } => {
  const start =
    page.after !== undefined
      ? rows.findIndex((row) => cursorOf(row) === page.after) + 1
      : (page.offset ?? 0)
  const items = rows.slice(start, start + page.limit)
  const last = items.at(-1)
  return {
    items,
    hasMore: start + page.limit < rows.length,
    endCursor: last === undefined ? null : cursorOf(last),
  }
}
