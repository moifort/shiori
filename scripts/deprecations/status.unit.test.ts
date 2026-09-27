import { describe, expect, test } from 'bun:test'
import { proposedFloorOf, statusOf } from './status'

const today = new Date('2026-11-20')
const live = { build: 1500, releasedOn: new Date('2026-11-01') }

describe('whether a deprecated element can go', () => {
  test('not while an operation of the app still asks for it', () => {
    expect(statusOf({ since: 'still-asked', live, today })).toEqual({ kind: 'still-asked' })
  })

  test('at once when no build ever asked for it', () => {
    expect(statusOf({ since: 0, live: undefined, today })).toEqual({ kind: 'removable' })
  })

  test('once a build without it has been on the App Store for two weeks', () => {
    expect(statusOf({ since: 1400, live, today })).toEqual({ kind: 'removable' })
  })

  test('not before the two weeks are over', () => {
    expect(statusOf({ since: 1400, live, today: new Date('2026-11-10') })).toEqual({
      kind: 'in-grace',
      until: new Date('2026-11-15'),
    })
  })

  test('not while the App Store still sells a build that asks for it', () => {
    expect(statusOf({ since: 1600, live, today })).toEqual({ kind: 'waiting-release' })
  })

  test('not before anything is on the App Store', () => {
    expect(statusOf({ since: 1400, live: undefined, today })).toEqual({ kind: 'waiting-release' })
  })

  test('is unknown without App Store Connect credentials', () => {
    expect(statusOf({ since: 1400, live: 'unknown', today })).toEqual({ kind: 'unknown' })
  })
})

describe('the proposed floor', () => {
  test('is the highest build among the removable elements', () => {
    expect(
      proposedFloorOf(
        [
          { since: 1400, status: { kind: 'removable' } },
          { since: 1450, status: { kind: 'removable' } },
          { since: 1600, status: { kind: 'waiting-release' } },
        ],
        1,
      ),
    ).toBe(1450)
  })

  test('never goes below the current floor', () => {
    expect(proposedFloorOf([{ since: 0, status: { kind: 'removable' } }], 1200)).toBe(1200)
  })
})
