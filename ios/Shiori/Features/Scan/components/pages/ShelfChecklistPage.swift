import SwiftUI

/// Every book of the photo, ticked unless the reader owns it already or its
/// title could not be read. The button says what the run will cost.
///
/// The tick is its own control, and the rest of the row opens the correction
/// sheet: a tap meant to tick never opens a sheet by accident.
struct ShelfChecklistPage: View {
    let viewModel: ShelfImportViewModel
    @State private var highlighted: Int?
    @State private var correcting: DetectedBook?
    @State private var allowanceAlert = false

    var body: some View {
        List {
            if let photo = viewModel.photo {
                Section {
                    ShelfPhoto(photo: photo, books: viewModel.books, highlighted: highlighted)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                ForEach(viewModel.books) { book in
                    row(book)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { addButton }
        .navigationTitle("\(viewModel.books.count) livres trouvés")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $correcting) { book in
            DetectedBookSheet(book: book, crop: viewModel.crop(of: book)) { title, authors in
                viewModel.correct(book.id, title: title, authors: authors)
            }
        }
        .alert("Pas assez de scans", isPresented: $allowanceAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Il vous reste \(viewModel.remainingScans ?? 0) scans ce mois-ci. Décochez des livres pour continuer.")
        }
    }

    private func row(_ book: DetectedBook) -> some View {
        let isTicked = viewModel.ticked.contains(book.id)
        return HStack(spacing: 12) {
            Button { viewModel.toggle(book.id) } label: {
                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isTicked ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isTicked ? "Décocher" : "Cocher")
            .accessibilityIdentifier("shelf-tick-\(book.id)")

            Group {
                if let crop = viewModel.crop(of: book) {
                    Image(uiImage: crop).resizable().scaledToFit()
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 32, height: 48)
            .clipShape(.rect(cornerRadius: 3))

            VStack(alignment: .leading, spacing: 2) {
                if book.isNamed, let title = book.title {
                    Text(title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    let details = [book.byline, book.seriesLabel].compactMap(\.self)
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Tranche illisible")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.orange)
                    Text("Touchez pour saisir le titre")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if book.owned {
                Text("Déjà chez vous")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15), in: .capsule)
                    .foregroundStyle(.green)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            highlighted = book.id
            correcting = book
        }
        .accessibilityIdentifier("shelf-row-\(book.id)")
    }

    private var addButton: some View {
        Button {
            if viewModel.exceedsAllowance { allowanceAlert = true } else { viewModel.addTicked() }
        } label: {
            Text("Ajouter \(viewModel.tickedCount) livres · \(viewModel.tickedCount) scans")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.tickedCount == 0)
        .padding()
        .background(.bar)
        .accessibilityIdentifier("shelf-add")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ShelfChecklistPage(viewModel: .preview())
    }
}
#endif
