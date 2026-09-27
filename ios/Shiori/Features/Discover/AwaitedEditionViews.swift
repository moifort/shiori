import SwiftUI

/// An awaited edition in a list: its cover, its title in the language awaited
/// once found and the original's under it, and where it stands.
struct AwaitedEditionRow: View {
    let edition: AwaitedEdition

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: edition.cover, width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(edition.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                if !edition.authors.isEmpty {
                    Text(edition.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if edition.title != edition.originalTitle {
                    Text("Titre original : \(edition.originalTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(edition.stateLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(edition.state == .available ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Découvrir's strip of the editions awaited in one format, drawn as the
/// friends' favourites are: covers that scroll sideways, the ones out first
/// with "Disponible" in green under them.
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
                            captionTint: edition.state == .available ? .green : nil
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

/// On a book's page, the editions of it the reader awaits: a row each, which
/// opens where an edition out is sold, and gives up the wait from its menu.
struct AwaitedEditionsSection: View {
    let awaited: [AwaitedEdition]
    let onStop: (AwaitedEdition) -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        if !awaited.isEmpty {
            Section {
                ForEach(awaited) { edition in
                    Button {
                        if let url = edition.storeURL { openURL(url) }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(edition.format.awaitedTitle)
                                    .foregroundStyle(.primary)
                                Text(edition.state == .unannounced
                                    ? edition.stateLine
                                    : "\(edition.title) · \(edition.stateLine)")
                                    .font(.caption)
                                    .foregroundStyle(edition.state == .available
                                        ? AnyShapeStyle(.green)
                                        : AnyShapeStyle(.secondary))
                            }
                        } icon: {
                            Image(systemName: edition.format == .audiobook ? "headphones" : "character.book.closed")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .disabled(edition.storeURL == nil)
                    .contextMenu {
                        if let url = edition.storeURL {
                            Button(edition.format.storeLabel, systemImage: "arrow.up.right.square") {
                                openURL(url)
                            }
                        }
                        Button("Ne plus guetter", systemImage: "bell.slash", role: .destructive) {
                            onStop(edition)
                        }
                    }
                    .accessibilityIdentifier("book-awaited-\(edition.format.rawValue)")
                }
            } footer: {
                Text("Vous serez prévenu le jour de sa sortie.")
            }
        }
    }
}

/// One awaited edition, opened from Découvrir: what it is, where it stands,
/// and — once out — where it is sold. The Audible sync brings a recording
/// bought into the library by itself, which ends the wait.
struct AwaitedEditionView: View {
    let edition: AwaitedEdition
    let onStop: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    BookCover(book: edition.cover, width: 96)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(edition.title).font(.title3.weight(.semibold))
                        if !edition.authors.isEmpty {
                            Text(edition.authors.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                        }
                        Text(edition.stateLine)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(edition.state == .available
                                ? AnyShapeStyle(.green)
                                : AnyShapeStyle(.secondary))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                LabeledContent("Titre original", value: edition.originalTitle)
                LabeledContent(
                    "Guetté",
                    value: edition.format == .audiobook
                        ? String(localized: "En livre audio")
                        : String(localized: "En livre")
                )
            }

            if let url = edition.storeURL {
                Section {
                    Button {
                        openURL(url)
                    } label: {
                        Label(
                            edition.format.storeLabel,
                            systemImage: edition.format == .audiobook ? "headphones" : "cart"
                        )
                    }
                    .accessibilityIdentifier("awaited-open-store")
                } footer: {
                    if edition.format == .audiobook {
                        Text("Une fois acheté, la synchronisation Audible l'ajoute à votre bibliothèque et il n'est plus guetté.")
                    }
                }
            }

            Section {
                Button("Ne plus guetter", systemImage: "bell.slash", role: .destructive) {
                    onStop()
                    dismiss()
                }
                .accessibilityIdentifier("awaited-stop")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(edition.format.awaitedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
        }
    }
}

/// Every edition awaited in one format, as "Voir les livres guettés" opens
/// them: the ones out, the ones announced, the ones not announced yet. A swipe
/// gives one up.
struct AwaitedEditionsListView: View {
    let format: ReleaseFormat
    let editions: [AwaitedEdition]
    let onOpen: (AwaitedEdition) -> Void
    let onStop: (AwaitedEdition) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            group("Disponibles", .available)
            group("Annoncés", .announced)
            group("Pas encore annoncés", .unannounced)
        }
        .listStyle(.insetGrouped)
        .overlay {
            if editions.isEmpty {
                EmptyStateView(
                    systemImage: format == .audiobook ? "headphones" : "character.book.closed",
                    title: "Aucun livre guetté",
                    message: "Guettez la version française d'un livre depuis sa fiche."
                )
            }
        }
        .navigationTitle("Livres guettés")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func group(_ title: LocalizedStringKey, _ state: AwaitedState) -> some View {
        let shown = editions.filter { $0.state == state }
        if !shown.isEmpty {
            Section(title) {
                ForEach(shown) { edition in
                    AwaitedEditionRow(edition: edition)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(edition) }
                        .accessibilityAddTraits(.isButton)
                        .swipeActions {
                            Button("Ne plus guetter", systemImage: "bell.slash", role: .destructive) {
                                onStop(edition)
                            }
                        }
                        .accessibilityIdentifier("awaited-row")
                }
            }
        }
    }
}
