import Foundation

/// What the reader changed on a saga in its edit form. A nil property was not
/// touched and is not sent.
struct SeriesCorrection: Equatable, Sendable {
    /// The edition's name, in the shared catalogue — or on the reader's
    /// volumes alone for a saga nobody catalogued.
    var name: String?
    /// The kind of object every volume the reader holds is. Never a recording.
    var format: BookFormat?
    /// The edition's description, in the shared catalogue.
    var description: BookCorrection.Change<String>?

    var isEmpty: Bool { self == SeriesCorrection() }
}
