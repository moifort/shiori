import SwiftUI

/// Découvrir's strip of the editions awaited in one format, drawn as the
/// friends' favourites are: covers that scroll sideways, the ones out first
/// with "Disponible" in green under them, the date of the ones announced in
/// orange.
struct AwaitedEditionsStrip: View {
    let editions: [AwaitedEdition]
    let onTapped: (AwaitedEdition) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(editions) { edition in
                    Button { onTapped(edition) } label: {
                        CoverTile(
                            book: edition.cover,
                            caption: edition.caption,
                            captionTint: edition.stateTint
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discover-awaited-tile")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

/// On a book's page, the editions of it the reader awaits that the web has
/// found, drawn as a saga's next volume is on its page: the cover, the format
/// awaited over the title, when it comes in orange — or "Disponible" in green —
/// and the calendar leaf on the trailing edge. One not announced yet draws
/// nothing: the binoculars in the corner of the page say it is awaited, and the
/// menu gives it up. A tap opens its page, as Découvrir opens it.
struct AwaitedEditionsSection: View {
    let awaited: [AwaitedEdition]
    let onStop: (AwaitedEdition) -> Void

    @Environment(\.openURL) private var openURL
    @State private var opened: AwaitedEdition?

    private var found: [AwaitedEdition] { awaited.filter { $0.state != .unannounced } }

    var body: some View {
        if !found.isEmpty {
            Section {
                ForEach(found) { edition in
                    Button { opened = edition } label: { AwaitedEditionReleaseRow(edition: edition) }
                        .tint(.primary)
                        .contextMenu {
                            if let url = edition.storeURL {
                                Button(edition.format.storeLabel, systemImage: "arrow.up.right.square") {
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
            .sheet(item: $opened) { edition in
                NavigationStack {
                    AwaitedEditionView(edition: edition) { onStop(edition) }
                }
            }
        }
    }
}

/// An awaited edition drawn as a saga's next volume is: the cover, the format
/// awaited over the title, when it comes in orange — or "Disponible" in green —
/// and the calendar leaf on the trailing edge while it is still to come.
struct AwaitedEditionReleaseRow: View {
    let edition: AwaitedEdition

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: edition.cover)
            VStack(alignment: .leading, spacing: 3) {
                Text(edition.format.awaitedTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(edition.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(edition.stateLine)
                    .foregroundStyle(edition.stateTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
                    .font(.subheadline.weight(.medium))
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            // Only what is still to come: once out, the green line says it.
            if edition.state == .announced, let date = edition.date {
                ReleaseDateBadge(date: date)
            }
        }
        .padding(.vertical, 4)
    }
}

/// One awaited edition, opened from Découvrir, drawn as a volume announced
/// is: where it stands pinned on its cover — orange while announced, green
/// once out — with the store's tag in its corner once it sells it, what it is a translation or a recording of, and
/// since when it is watched for. Only what is known is drawn. "Ne plus suivre"
/// sits in the corner, asked for twice as a saga's deletion is. The Audible
/// sync brings a recording bought into the library by itself, which ends the
/// wait.
struct AwaitedEditionView: View {
    let edition: AwaitedEdition
    let onStop: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmStop = false

    var body: some View {
        List {
            BookHeaderSection(
                book: edition.cover,
                state: edition.pageState,
                releaseDate: edition.state == .announced ? edition.date : nil,
                storeLink: edition.storeURL.map { .init(name: edition.format.storeName, url: $0, tint: edition.format.storeTint) }
            ) {
                if edition.title != edition.originalTitle {
                    LabeledInfoRow(title: "Titre original", value: edition.originalTitle, icon: "character.book.closed")
                }
                if let awaitedAt = edition.awaitedAt {
                    LabeledInfoRow(
                        title: "Suivi depuis le",
                        value: awaitedAt.formatted(date: .abbreviated, time: .omitted),
                        icon: "binoculars"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
        .navigationTitle(edition.format.awaitedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                ToolbarIconButton(title: "Ne plus suivre", systemImage: "bell.slash") {
                    confirmStop = true
                }
                .tint(.red)
                .accessibilityIdentifier("awaited-stop")
                // Attached to the button, as a saga's deletion is: the dialog
                // rises from the control that asked.
                .confirmationDialog(
                    "Ne plus suivre ce livre ?",
                    isPresented: $confirmStop,
                    titleVisibility: .visible
                ) {
                    Button("Ne plus suivre", role: .destructive) {
                        onStop()
                        dismiss()
                    }
                    .accessibilityIdentifier("choice-stop-awaiting")
                    Button("Annuler", role: .cancel) {}
                } message: {
                    Text("Vous ne serez plus prévenu de sa sortie.")
                }
            }
        }
    }
}

extension AwaitedEdition {
    /// Where it stands, pinned on its cover on its page.
    var pageState: BookState {
        BookState(text: stateLine, tint: stateTint ?? .gray)
    }

    static let preview = AwaitedEdition(
        id: "preview",
        format: .audiobook,
        state: .announced,
        title: "Opération Bounce House",
        originalTitle: "Operation Bounce House",
        originalLanguage: .en,
        authors: ["Matt Dinniman"],
        date: "2026-11-05",
        coverURL: nil,
        storeURL: nil,
        awaitedAt: .now.addingTimeInterval(-3 * 86400),
        bookId: "book",
        ownerId: "me"
    )
}

#Preview("Awaited edition") {
    NavigationStack {
        AwaitedEditionView(edition: .preview) {}
    }
}
