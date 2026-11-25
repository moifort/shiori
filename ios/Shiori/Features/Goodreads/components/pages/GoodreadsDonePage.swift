import SwiftUI

/// How an import ended, set out as the preview was: the wall of covers, the
/// figures, then a rail of what was added and one of the books whose cover
/// is the app's typeset stand-in. Pure and previewable.
struct GoodreadsDonePage: View {
    let outcome: GoodreadsImportOutcome
    let preview: GoodreadsPreview
    let choices: GoodreadsChoices
    var onShowLibrary: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    GoodreadsMosaic(books: added.prefix(40).map(\.cover))
                    VStack(spacing: 4) {
                        Text("\(outcome.imported) livres importés")
                            .font(.largeTitle.weight(.heavy))
                            .multilineTextAlignment(.center)
                        Label {
                            Text("Depuis Goodreads")
                        } icon: {
                            Image("goodreads-logo").resizable().scaledToFit().frame(width: 15, height: 15)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                }
                .foregroundStyle(.white)

                FiguresLine(items: [
                    .init(value: FiguresLine.compact(count(.read)), label: String(localized: "Lus")),
                    .init(value: FiguresLine.compact(count(.reading)), label: String(localized: "En cours")),
                    .init(value: FiguresLine.compact(outcome.wished), label: String(localized: "Envies")),
                    .init(value: FiguresLine.compact(count(.dropped)), label: String(localized: "Abandonnés")),
                ])
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 30) {
                    rail("Ajoutés", count: outcome.imported, rows: added)
                    if outcome.completed > 0 {
                        rail("Déjà chez vous", count: outcome.completed, rows: preview.heldRows, caption: String(localized: "Complété"))
                    }
                }
                .padding(.top, 30)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) {
            Button(action: onShowLibrary) {
                Text("Voir ma bibliothèque").frame(maxWidth: .infinity)
            }
            .buttonStyle(.actionWide)
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden()
        .accessibilityIdentifier("goodreads-done")
    }

    /// The rows the import wrote as books or wishes.
    private var added: [GoodreadsRow] {
        preview.rows.filter { choices.keys.contains($0.key) && $0.verdict != .held && !choices.sameBooks.contains($0.key) }
    }

    private func count(_ status: ReadingStatus) -> Int {
        added.filter { $0.status(toRead: choices.toRead) == status }.count
    }

    private func rail(_ title: LocalizedStringKey, count: Int, rows: [GoodreadsRow], caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title2.weight(.bold))
                Spacer()
                Text(count, format: .number).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 13) {
                    ForEach(rows.prefix(20)) { row in
                        PosterCover(book: row.heldCover ?? row.cover, caption: caption ?? row.caption(toRead: choices.toRead))
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    NavigationStack {
        GoodreadsDonePage(
            outcome: .preview,
            preview: .preview,
            choices: GoodreadsChoices(preview: .preview),
            onShowLibrary: {}
        )
    }
    .environment(\.colorScheme, .dark)
}
