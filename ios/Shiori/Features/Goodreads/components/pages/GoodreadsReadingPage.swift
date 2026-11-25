import SwiftUI

/// The file being read, as the checklist the onboarding ends on: each line
/// ticks off when its work is over, and the covers and sagas go on in the
/// background once the preview can open. Pure and previewable.
struct GoodreadsReadingPage: View {
    let lines: [PreparationLine]

    var body: some View {
        ZStack {
            CoverWall()
            CoverVeil(covering: true)
            VStack(spacing: 0) {
                Image("goodreads-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .frame(width: 84, height: 84)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 19))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                Text("Préparation de votre import")
                    .font(.headline)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                PreparationChecklist(lines: lines)
                Text("L'aperçu s'ouvre dès la comparaison faite. Les couvertures se cherchent ensuite en arrière-plan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 20)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityIdentifier("goodreads-reading")
    }
}

extension GoodreadsReadingPage {
    /// The lines for a read under way, or done with what it found.
    static func lines(found preview: GoodreadsPreview?, reading: Bool) -> [PreparationLine] {
        guard let preview else {
            return [
                PreparationLine(id: "file", label: "Lecture du fichier", state: reading ? .working : .waiting),
                PreparationLine(id: "shelves", label: "Vos étagères", state: .waiting),
                PreparationLine(id: "compare", label: "Comparaison avec vos livres", state: .waiting),
                PreparationLine(id: "covers", label: "Couvertures et séries", state: .waiting),
            ]
        }
        let books = String(localized: "\(preview.rows.count) livres")
        let shelves = String(
            localized: "\(preview.readCount) lus · \(preview.readingCount) en cours · \(preview.toReadCount) à lire · \(preview.droppedCount) abandonnés"
        )
        return [
            PreparationLine(id: "file", label: "Lecture du fichier", state: .done, detail: books),
            PreparationLine(id: "shelves", label: "Vos étagères", state: .done, detail: shelves),
            PreparationLine(id: "compare", label: "Comparaison avec vos livres", state: .done),
            PreparationLine(id: "covers", label: "Couvertures et séries", state: .continuing),
        ]
    }
}

#Preview("En cours") {
    GoodreadsReadingPage(lines: GoodreadsReadingPage.lines(found: nil, reading: true))
}

#Preview("Lu") {
    GoodreadsReadingPage(lines: GoodreadsReadingPage.lines(found: .preview, reading: false))
}
