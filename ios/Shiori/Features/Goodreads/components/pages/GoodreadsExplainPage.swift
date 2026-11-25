import SwiftUI

/// How to get the Goodreads export file, and the two ways on: Goodreads' own
/// page in Safari, and the file picker. Pure and previewable.
struct GoodreadsExplainPage: View {
    var onChooseFile: () -> Void
    var onOpenGoodreads: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Image("goodreads-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .frame(width: 64, height: 64)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
                    .padding(.top, 8)

                Text("Votre bibliothèque Goodreads")
                    .font(.title.bold())
                    .padding(.top, 16)
                Text("Goodreads ne partage pas vos livres avec d'autres apps : tout passe par son fichier d'export, qui garde vos étagères, vos notes et vos dates de lecture.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    step(1, "Ouvrez la page d'export", detail: "Connecté à votre compte Goodreads.")
                    Divider().padding(.leading, 44)
                    step(2, "Touchez « Export Library »", detail: "Le fichier se prépare, quelques minutes pour une grande bibliothèque.")
                    Divider().padding(.leading, 44)
                    step(3, "Touchez « Your export from… »", detail: "Le fichier .csv arrive dans vos Téléchargements.")
                }
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 26))
                .padding(.top, 20)

                Text("Goodreads réserve cette page à l'ordinateur. Si son site mobile s'affiche, touchez aA › Version pour ordinateur. Depuis Fichiers, Partager › Shiori fonctionne aussi.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: onChooseFile) {
                    Text("Choisir le fichier").frame(maxWidth: .infinity)
                }
                .buttonStyle(.actionWide)
                .controlSize(.large)
                .accessibilityIdentifier("goodreads-choose-file")
                Button(action: onOpenGoodreads) {
                    Text("Ouvrir Goodreads").frame(maxWidth: .infinity)
                }
                .buttonStyle(.actionGlass)
                .controlSize(.large)
                .accessibilityIdentifier("goodreads-open-site")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .navigationTitle("Goodreads")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number, format: .number)
                .font(.subheadline.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(Color(.tertiarySystemFill), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        GoodreadsExplainPage(onChooseFile: {}, onOpenGoodreads: {})
    }
    .environment(\.colorScheme, .dark)
}
