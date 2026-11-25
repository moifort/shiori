import SwiftUI

/// What the export holds, set out as a book's page is: a wall of the covers
/// found at the head, the figures under the title as the home sets its year,
/// a rail for each verdict, then the shelves and what to carry over, in boxes.
/// Pure and previewable: it takes the preview and the choices, and says what
/// was tapped.
struct GoodreadsPreviewPage: View {
    enum Action {
        case showBooks(GoodreadsBooksPage.Filter)
        case decide(GoodreadsRow)
        case importBooks
    }

    let preview: GoodreadsPreview
    @Binding var choices: GoodreadsChoices
    var isImporting = false
    let onAction: (Action) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                FiguresLine(items: [
                    .init(value: FiguresLine.compact(preview.readCount), label: String(localized: "Lus")),
                    .init(value: FiguresLine.compact(preview.readingCount), label: String(localized: "En cours")),
                    .init(value: FiguresLine.compact(preview.toReadCount), label: String(localized: "À lire")),
                    .init(value: FiguresLine.compact(preview.ratedCount), label: String(localized: "Notés")),
                ])
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 30) {
                    rail(
                        "Nouveaux",
                        rows: preview.newRows,
                        filter: .new
                    ) { row in
                        PosterCover(book: row.cover, caption: row.caption(toRead: choices.toRead))
                    }
                    if !preview.uncertainRows.isEmpty {
                        rail(
                            "À vérifier",
                            rows: preview.uncertainRows,
                            filter: .uncertain,
                            warns: true
                        ) { row in
                            Button { onAction(.decide(row)) } label: {
                                PosterCover(book: row.heldCover ?? row.cover, caption: caption(ofUncertain: row))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !preview.heldRows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            rail("Déjà chez vous", rows: preview.heldRows, filter: .held) { row in
                                PosterCover(book: row.heldCover ?? row.cover, caption: String(localized: "Complété"))
                            }
                            footnote("Ils prennent la note et la date de Goodreads quand ils n'en ont pas. Un livre papier et sa version Kindle restent un seul livre.")
                        }
                    }
                    shelvesSection
                    carriedSection
                }
                .padding(.top, 30)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) { importBar }
        .accessibilityIdentifier("goodreads-preview")
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottom) {
            GoodreadsMosaic(books: preview.rows.prefix(40).map(\.cover))
            VStack(spacing: 4) {
                Text("\(preview.rows.count) livres")
                    .font(.largeTitle.weight(.heavy))
                Label {
                    Text("Votre export Goodreads")
                } icon: {
                    Image("goodreads-logo").resizable().scaledToFit().frame(width: 15, height: 15)
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.bottom, 4)
        }
        .foregroundStyle(.white)
    }

    // MARK: - Rails

    private func rail<Poster: View>(
        _ title: LocalizedStringKey,
        rows: [GoodreadsRow],
        filter: GoodreadsBooksPage.Filter,
        warns: Bool = false,
        @ViewBuilder poster: @escaping (GoodreadsRow) -> Poster
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { onAction(.showBooks(filter)) } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(warns ? Color.orange : Color.primary)
                    Spacer()
                    Text("\(rows.count) ›")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 13) {
                    ForEach(rows.prefix(20)) { poster($0) }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func caption(ofUncertain row: GoodreadsRow) -> String {
        if choices.sameBooks.contains(row.key) { return String(localized: "Même livre") }
        if choices.keys.contains(row.key) { return String(localized: "Deux livres") }
        return String(localized: "Déjà chez vous ?")
    }

    // MARK: - Sections

    private var shelvesSection: some View {
        section("Étagères", footer: "« À lire » est souvent une liste d'envies sur Goodreads. Si vous possédez ces livres, choisissez Pile à lire.") {
            shelfRow("Lus", count: preview.readCount, target: "Lu")
            Divider().padding(.leading, 16)
            shelfRow("En cours", count: preview.readingCount, target: "En cours")
            Divider().padding(.leading, 16)
            MenuPicker(
                selection: $choices.toRead,
                options: GoodreadsChoices.ToRead.allCases,
                label: { $0 == .wishlist ? String(localized: "Envies") : String(localized: "Pile à lire") }
            ) {
                shelfLabel("À lire", count: preview.toReadCount)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityIdentifier("goodreads-to-read")
            if preview.droppedCount > 0 {
                Divider().padding(.leading, 16)
                shelfRow("Abandonnés", count: preview.droppedCount, target: "Abandonné")
            }
        }
    }

    private var carriedSection: some View {
        section("Repris de Goodreads") {
            toggle("Notes", detail: String(localized: "\(preview.ratedCount) livres notés"), isOn: $choices.keepRatings)
            Divider().padding(.leading, 16)
            toggle("Dates de lecture", detail: String(localized: "\(preview.datedCount) livres datés"), isOn: $choices.keepDates)
            Divider().padding(.leading, 16)
            toggle("Critiques", detail: String(localized: "\(preview.reviewedCount) critiques, dans la note du livre"), isOn: $choices.keepReviews)
        }
    }

    private func section<Content: View>(
        _ title: LocalizedStringKey,
        footer: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)
            VStack(spacing: 0) { content() }
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 18))
                .padding(.horizontal, 20)
            if let footer { footnote(footer) }
        }
    }

    private func shelfLabel(_ title: LocalizedStringKey, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text("\(count) livres")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func shelfRow(_ title: LocalizedStringKey, count: Int, target: LocalizedStringKey) -> some View {
        HStack {
            shelfLabel(title, count: count)
            Spacer()
            Text(target).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func toggle(_ title: LocalizedStringKey, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func footnote(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 34)
    }

    // MARK: - Bar

    private var importBar: some View {
        let count = choices.importedCount(in: preview)
        return Button { onAction(.importBooks) } label: {
            ZStack {
                Text(count == 0 ? String(localized: "Compléter vos livres") : String(localized: "Importer \(count) livres"))
                    .opacity(isImporting ? 0 : 1)
                if isImporting { ProgressView() }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.actionWide)
        .controlSize(.large)
        .disabled(isImporting || choices.keys.isEmpty)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityIdentifier("goodreads-import")
    }
}

#Preview {
    @Previewable @State var choices = GoodreadsChoices(preview: .preview)
    GoodreadsPreviewPage(preview: .preview, choices: $choices) { _ in }
        .environment(\.colorScheme, .dark)
}
