import SwiftUI

/// Adding a book without a photo, connected: `ManualAddSheet` collects it,
/// the client adds it.
struct ManualAddScreen: View {
    var onAdded: (Book) -> Void
    var client: BookClient = .live

    var body: some View {
        ManualAddSheet { draft in
            do {
                let book = try await client.add(draft)
                track(.bookAdded(source: .manual))
                onAdded(book)
                return nil
            } catch {
                return reportError(error)
            }
        }
    }
}
