/** How long a build that no longer asks for an element must have been on the
 *  App Store before the builds that still ask are sent to update: iOS automatic
 *  updates have reached nearly everyone by then. */
export const GRACE_DAYS = 14

const DAY_MS = 24 * 60 * 60 * 1000

/** The build on sale on the App Store, and the day it was released. */
export type LiveBuild = { build: number; releasedOn: Date }

/** The first build that no longer asks for the element — `0` when no build ever
 *  did — or `still-asked` when an operation of the app still selects it. */
export type Since = number | 'still-asked'

export type Status =
  | { kind: 'still-asked' }
  | { kind: 'removable' }
  | { kind: 'in-grace'; until: Date }
  | { kind: 'waiting-release' }
  | { kind: 'unknown' }

export const statusOf = ({
  since,
  live,
  today,
}: {
  since: Since
  live: LiveBuild | undefined | 'unknown'
  today: Date
}): Status => {
  if (since === 'still-asked') return { kind: 'still-asked' }
  if (since === 0) return { kind: 'removable' }
  if (live === 'unknown') return { kind: 'unknown' }
  if (!live || live.build < since) return { kind: 'waiting-release' }
  const until = new Date(live.releasedOn.getTime() + GRACE_DAYS * DAY_MS)
  return until <= today ? { kind: 'removable' } : { kind: 'in-grace', until }
}

/** The floor the removal commit sets: the highest build among the elements
 *  that can go, never below the floor already in force. */
export const proposedFloorOf = (
  rows: readonly { since: Since; status: Status }[],
  current: number,
): number =>
  Math.max(
    current,
    ...rows.flatMap((row) =>
      row.status.kind === 'removable' && typeof row.since === 'number' ? [row.since] : [],
    ),
  )
