import SwiftUI

/// Everything the shelf checklist can ask for.
enum ShelfChecklistAction {
    case toggle(Int)
    /// A spine read wrong, or not at all, typed by the reader.
    case correct(Int, title: String, authors: [String])
    case addTicked
}

/// Every book of the photo, ticked unless the reader owns it already or its
/// title could not be read. The button says what the run will cost.
///
/// The tick is its own control, and the rest of the row opens the correction
/// sheet: a tap meant to tick never opens a sheet by accident.
struct ShelfChecklistPage: View {
    let photo: UIImage?
    let books: [DetectedBook]
    let ticked: Set<Int>
    /// What is left of the allowance; nil when unknown.
    let remainingScans: Int?
    /// The book's spine cut out of the photo, when it could be.
    let crop: (DetectedBook) -> UIImage?
    let onAction: (ShelfChecklistAction) -> Void

    @State private var highlighted: Int?
    @State private var correcting: DetectedBook?
    @State private var allowanceAlert = false

    /// More books ticked than scans left: the page says how many remain rather
    /// than starting a run that would stop halfway.
    private var exceedsAllowance: Bool {
        remainingScans.map { ticked.count > $0 } ?? false
    }

    var body: some View {
        List {
            if let photo {
                Section {
                    ShelfPhoto(photo: photo, books: books, highlighted: highlighted)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                ForEach(books) { book in
                    row(book)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { addButton }
        .navigationTitle("\(books.count) livres trouvés")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $correcting) { book in
            DetectedBookSheet(book: book, crop: crop(book)) { title, authors in
                onAction(.correct(book.id, title: title, authors: authors))
            }
        }
        .alert("Pas assez de scans", isPresented: $allowanceAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Il vous reste \(remainingScans ?? 0) scans ce mois-ci. Décochez des livres pour continuer.")
        }
    }

    private func row(_ book: DetectedBook) -> some View {
        let isTicked = ticked.contains(book.id)
        return HStack(spacing: 12) {
            Button { onAction(.toggle(book.id)) } label: {
                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isTicked ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isTicked ? "Décocher" : "Cocher")
            .accessibilityIdentifier("shelf-tick-\(book.id)")

            Group {
                if let crop = crop(book) {
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
            if exceedsAllowance { allowanceAlert = true } else { onAction(.addTicked) }
        } label: {
            Text("Ajouter \(ticked.count) livres · \(ticked.count) scans")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(ticked.isEmpty)
        .padding()
        .background(.bar)
        .accessibilityIdentifier("shelf-add")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ShelfChecklistPage(
            photo: ShelfImportFixtures.photo,
            books: ShelfImportFixtures.books,
            ticked: ShelfImportFixtures.ticked,
            remainingScans: 94,
            crop: { _ in nil }
        ) { _ in }
    }
}
#endif
