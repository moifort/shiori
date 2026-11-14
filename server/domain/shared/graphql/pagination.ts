/** How many rows a page of a list holds: what the app asked for, else the
 *  list's own default, never below one nor above the list's ceiling — a client
 *  asking for ten thousand rows gets the ceiling, not a timeout. */
export const pageSizeOf = (
  asked: number | null | undefined,
  { fallback, ceiling }: { fallback: number; ceiling: number },
): number => Math.max(1, Math.min(asked ?? fallback, ceiling))
