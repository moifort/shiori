import SwiftUI

/// On a book's page, the editions of it the reader awaits that the web has
/// found, drawn as a saga's next volume is on its page: the cover, the format
/// awaited over the title, when it comes in orange — or "Disponible" in green —
/// and the calendar leaf on the trailing edge. One not announced yet draws
/// nothing: the binoculars in the corner of the page say it is awaited, and the
/// menu gives it up. A tap opens its page, as Découvrir opens it.
struct AwaitedEditionsSection: View {
    let awaited: [AwaitedEdition]
    let onOpen: (AwaitedEdition) -> Void
    let onStop: (AwaitedEdition) -> Void

    @Environment(\.openURL) private var openURL

    private var found: [AwaitedEdition] { awaited.filter { $0.state != .unannounced } }

    var body: some View {
        if !found.isEmpty {
            Section {
                ForEach(found) { edition in
                    Button { onOpen(edition) } label: { AwaitedEditionReleaseRow(edition: edition) }
                        .tint(.primary)
                        .contextMenu {
                            if let url = edition.storeURL {
                                Button(edition.format.storeName, systemImage: "arrow.up.right.square") {
                                    openURL(url)
                                }
                            }
                            Button("Ne plus suivre", systemImage: "bell.slash", role: .destructive) {
                                onStop(edition)
                            }
                        }
                        .accessibilityIdentifier("book-awaited-\(edition.format.rawValue)")
                }
            } header: {
                Text("Prochaines sorties")
            }
        }
    }
}

#Preview {
    List {
        AwaitedEditionsSection(awaited: [.preview], onOpen: { _ in }, onStop: { _ in })
    }
}
