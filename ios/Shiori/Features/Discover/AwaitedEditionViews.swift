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
                    .foregroundStyle(edition.stateTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

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
                    Group {
                        // A link once a store sells it; a plain line until then,
                        // drawn at full strength rather than greyed as disabled.
                        if let url = edition.storeURL {
                            Button { openURL(url) } label: { line(edition) }
                        } else {
                            line(edition)
                        }
                    }
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

    private func line(_ edition: AwaitedEdition) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(edition.format.awaitedTitle)
                    .foregroundStyle(.primary)
                Text(edition.state == .unannounced
                    ? edition.stateLine
                    : "\(edition.title) · \(edition.stateLine)")
                    .font(.caption)
                    .foregroundStyle(edition.stateTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
            }
        } icon: {
            Image(systemName: edition.format == .audiobook ? "headphones" : "character.book.closed")
                .foregroundStyle(Color.accentColor)
        }
    }
}

/// One awaited edition, opened from Découvrir, drawn as a volume announced
/// is: where it stands on top — orange while announced, green once out —
/// then the book's own section, with the store's tag in its corner once it
/// sells it, what it is a translation or a recording of, and when it was
/// awaited. Only what is known is drawn. "Ne plus guetter" sits in the corner,
/// asked for twice as a saga's deletion is. The Audible sync brings a
/// recording bought into the library by itself, which ends the wait.
struct AwaitedEditionView: View {
    let edition: AwaitedEdition
    let onStop: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmStop = false

    var body: some View {
        List {
            Section {
                Label(edition.stateLine, systemImage: edition.state == .available ? "checkmark.circle" : "clock")
                    .foregroundStyle(edition.stateTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("awaited-state")
            }

            ReadOnlyBookHeader(
                book: edition.cover,
                storeLink: edition.storeURL.map { .init(name: edition.format.storeName, url: $0) }
            ) {
                if edition.title != edition.originalTitle {
                    LabeledInfoRow(title: "Titre original", value: edition.originalTitle, icon: "character.book.closed")
                }
                if let awaitedAt = edition.awaitedAt {
                    LabeledInfoRow(
                        title: "Ajouté le",
                        value: awaitedAt.formatted(date: .abbreviated, time: .omitted),
                        icon: "tray.and.arrow.down"
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
                ToolbarIconButton(title: "Ne plus guetter", systemImage: "bell.slash") {
                    confirmStop = true
                }
                .tint(.red)
                .accessibilityIdentifier("awaited-stop")
                // Attached to the button, as a saga's deletion is: the dialog
                // rises from the control that asked.
                .confirmationDialog(
                    "Ne plus guetter ce livre ?",
                    isPresented: $confirmStop,
                    titleVisibility: .visible
                ) {
                    Button("Ne plus guetter", role: .destructive) {
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
