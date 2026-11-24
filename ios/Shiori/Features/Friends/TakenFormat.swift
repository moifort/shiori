import Foundation

extension BookFormat {
    /// The two ways a friend's book can be taken: in print — this format, or a
    /// plain book when this one is a recording — and as a recording.
    var takenAs: [BookFormat] {
        [self == .audiobook ? .book : self, .audiobook]
    }
}

extension FriendSaga {
    /// What its first volume is, which is the one a "+" takes.
    var takenFormat: BookFormat {
        volumes.first?.format ?? (isAudio ? .audiobook : .book)
    }
}
