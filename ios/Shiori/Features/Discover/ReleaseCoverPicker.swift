import SwiftUI

/// What picking a cover for a book nobody here holds asks of the server, as
/// closures: `.live` goes through `ReleaseAPI`, `.preview` answers from the
/// fixtures.
struct ReleaseCoverClient: Sendable {
    var choices: @Sendable (_ key: String, _ drawn: URL?) async throws -> [CoverChoice]
    /// Answers the cover now drawn, for every reader.
    var choose: @Sendable (_ key: String, URL) async throws -> URL

    static let live = ReleaseCoverClient(
        choices: { try await ReleaseAPI.coverChoices(key: $0, drawn: $1) },
        choose: { try await ReleaseAPI.chooseCover(key: $0, url: $1) }
    )

    static let preview = ReleaseCoverClient(
        choices: { _, _ in CoverChoice.previews },
        choose: { _, url in url }
    )
}

/// The cover picker of a book's "…" menu, for a book nobody here holds — a
/// wish, an edition awaited, a discovery, a winner, a volume announced: the
/// covers found for its release, the one drawn first. The cover picked is
/// the release's, drawn for every reader in every list.
private struct ReleaseCoverPicker: ViewModifier {
    @Binding var isPresented: Bool
    /// The book as the page draws it.
    let book: Book
    let releaseKey: String
    let client: ReleaseCoverClient
    let onChosen: (URL) -> Void

    @State private var choices: [CoverChoice]?
    @State private var loadFailed: String?

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            CoverPickerSheet(book: book, choices: choices, loadFailed: loadFailed) { choice in
                await choose(choice)
            }
            .task { await load() }
        }
    }

    private func load() async {
        choices = nil
        loadFailed = nil
        do {
            choices = try await client.choices(releaseKey, book.coverURL)
        } catch {
            loadFailed = reportError(error)
        }
    }

    /// Nil once drawn with it, or the message the picker shows, open still.
    private func choose(_ choice: CoverChoice) async -> String? {
        do {
            onChosen(try await client.choose(releaseKey, choice.url))
            return nil
        } catch let error as APIError where error.domainCode == "COVER_NOT_AN_IMAGE" {
            // The link to a shop's page, pasted for its cover: the reader's
            // slip, nothing for Sentry.
            return String(localized: "Cette adresse mène à une page, pas à une image. Ouvrez l'image de la couverture seule, puis copiez son adresse.")
        } catch {
            return reportError(error)
        }
    }
}

extension View {
    /// Presents the cover picker of a book nobody here holds while
    /// `isPresented`, and hands the cover picked to `onChosen`.
    func releaseCoverPicker(
        isPresented: Binding<Bool>,
        book: Book,
        releaseKey: String,
        client: ReleaseCoverClient = .live,
        onChosen: @escaping (URL) -> Void
    ) -> some View {
        modifier(ReleaseCoverPicker(
            isPresented: isPresented,
            book: book,
            releaseKey: releaseKey,
            client: client,
            onChosen: onChosen
        ))
    }
}
