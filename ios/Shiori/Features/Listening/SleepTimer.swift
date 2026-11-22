import Foundation

/// The sleep timer's schedule: the listening plays at full volume, then, over
/// its last seconds, fades out to silence, which warns a listener half asleep
/// that it is about to stop, and pauses once the silence is reached.
///
/// Pure: the player asks it the volume at a given time and whether the fade
/// has begun, and does the rest.
struct SleepTimer: Equatable {
    /// What the timer was set to, in minutes.
    let minutes: Int
    /// When the player pauses.
    let endsAt: Date

    /// How long the volume takes to fall to silence before the pause.
    static let fadeDuration: TimeInterval = 5

    init(minutes: Int, from start: Date) {
        self.minutes = minutes
        endsAt = start.addingTimeInterval(TimeInterval(minutes * 60))
    }

    /// When the volume starts to fall: never before the timer was set, for a
    /// timer shorter than the fade.
    var fadeStartsAt: Date {
        let fade = min(Self.fadeDuration, TimeInterval(minutes * 60))
        return endsAt.addingTimeInterval(-fade)
    }

    /// Whether the volume is falling at `now`.
    func isFading(at now: Date) -> Bool {
        now >= fadeStartsAt && now < endsAt
    }

    /// Whether the timer has run out at `now`: the player pauses.
    func isOver(at now: Date) -> Bool {
        now >= endsAt
    }

    /// The player's volume at `now`, from 1 down to 0. The fall follows the
    /// square of the time left, which the ear hears as a steady fade rather
    /// than one that lingers loud and drops at the end.
    func volume(at now: Date) -> Float {
        let span = endsAt.timeIntervalSince(fadeStartsAt)
        guard span > 0 else { return now >= endsAt ? 0 : 1 }
        let left = min(max(endsAt.timeIntervalSince(now) / span, 0), 1)
        return Float(left * left)
    }
}
