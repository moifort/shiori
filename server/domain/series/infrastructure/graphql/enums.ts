import { builder } from '~/domain/shared/graphql/builder'

export const VolumeKindEnum = builder.enumType('VolumeKind', {
  description:
    'Where a volume sits in a saga.\n\n' +
    'Only `MAIN` belongs to the numbered spine; everything else orbits it and ' +
    'usually carries no number, which is why `volume` is nullable. The series ' +
    'screen renders the spine first and the rest under "Related works".',
  values: {
    MAIN: { value: 'main', description: 'A numbered volume of the main story.' },
    PREQUEL: {
      value: 'prequel',
      description: 'Set before the main story, often published later.',
    },
    SPIN_OFF: {
      value: 'spin-off',
      description: 'A side story in the same world, outside the numbering.',
    },
    NOVELLA: { value: 'novella', description: 'A short work tied to the saga.' },
    COMPANION: {
      value: 'companion',
      description: 'A guide, atlas, or artbook rather than a story.',
    },
  } as const,
})

export const SeriesStateEnum = builder.enumType('SeriesState', {
  description:
    'Where the reader stands on a saga.\n\n' +
    'Derived per request from what they own, never stored. `NOT_STARTED` means no ' +
    'owned volume has been opened yet. `COMPLETE` means every ' +
    'published volume has been read; an announced but unpublished volume does not ' +
    'hold a saga open, because a reader who is up to date has finished it. ' +
    '`UNFOLLOWED` is the reader setting the saga aside, and overrides the rest.',
  values: {
    NOT_STARTED: { value: 'not-started', description: 'No owned volume has been opened.' },
    IN_PROGRESS: { value: 'in-progress', description: 'Published volumes remain unread.' },
    COMPLETE: { value: 'complete', description: 'Every published volume has been read.' },
    UNFOLLOWED: {
      value: 'unfollowed',
      description:
        'The reader stopped following the saga (`setSeriesFollowed`). Whatever their ' +
        'volumes say, it is out of the sagas in progress and of the finished ones. ' +
        'Its volumes keep their own statuses.',
    },
  } as const,
})
