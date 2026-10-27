import Foundation

/// The narrator a "Lu par" line opens: the key the page is asked by, and the
/// name its title shows while it loads — and the page is drawn from, for a
/// narrator the reader holds nothing of, read on a friend's recording.
struct NarratorDestination: Hashable, Identifiable {
    let key: String
    let name: String
    var id: String { key }
}
