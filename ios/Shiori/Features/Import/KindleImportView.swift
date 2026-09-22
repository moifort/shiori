import SwiftUI
import UniformTypeIdentifiers

/// Cataloguing a Kindle library from the file Amazon hands its customers.
///
/// There is no account to connect and no nightly sync, and the screen says so
/// rather than letting the reader look for a sign-in button that will never
/// exist: Amazon publishes no Kindle library API, and the Audible connection
/// reaches nothing on that side. What every customer can get is a data export,
/// which arrives as a handful of CSVs in an archive.
///
/// The import proposes and the reader disposes, as a scan does: the file is read
/// into a list of titles, nothing is saved until they tick.
struct KindleImportView: View {
    /// Called with the books that were catalogued, so the library refreshes
    /// itself. Not called when nothing was imported.
    let onImported: ([Book]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var books: [KindleBook] = []
    @State private var selected: Set<String> = []
    @State private var csv: String?
    @State private var isReading = false
    @State private var isImporting = false
    @State private var showFileImporter = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Importer depuis Kindle")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                            dismiss()
                        }
                    }
                    if !books.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("Tout sélectionner", action: selectAll)
                                Button("Tout désélectionner") { selected = [] }
                                Button("Autre fichier") { showFileImporter = true }
                            } label: {
                                Label("Options", systemImage: "ellipsis.circle")
                            }
                            .accessibilityIdentifier("kindle-options")
                        }
                    }
                }
                // Amazon serves the export as CSV. Plain text is accepted too:
                // the archive has been known to hand out .txt with commas in it.
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.commaSeparatedText, .plainText]
                ) { result in
                    Task { await read(result) }
                }
                .alert(
                    "Fichier illisible",
                    isPresented: .init(
                        get: { errorMessage != nil },
                        set: { if !$0 { errorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isReading {
            ProgressView("Lecture du fichier...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if books.isEmpty {
            instructions
        } else {
            picker
        }
    }

    /// How to get the file, in the order the reader has to do it. Written out
    /// because nobody knows this path exists, and an "import your Kindle
    /// library" button that opens a file browser with no explanation is a dead
    /// end for everyone who has never asked Amazon for their data.
    private var instructions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label {
                    Text("Amazon ne donne accès à aucune bibliothèque Kindle depuis une autre application. Ce qu'il fournit, c'est un export de vos données, à demander une fois.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .labelStyle(.caption)

                VStack(alignment: .leading, spacing: 14) {
                    step(1, "Sur amazon.fr, ouvrez « Demander vos données ».")
                    step(2, "Demandez la catégorie des contenus numériques, puis attendez le courriel d'Amazon. Il peut mettre quelques jours.")
                    step(3, "Téléchargez l'archive et dépliez-la.")
                    step(4, "Revenez ici et choisissez le fichier qui liste les contenus possédés.")
                }

                Link(destination: URL(string: "https://www.amazon.fr/hz/privacy-central/data-requests/preview.html")!) {
                    Label("Ouvrir la page Amazon", systemImage: "safari")
                }
                .font(.subheadline)

                Button {
                    showFileImporter = true
                } label: {
                    Label("Choisir le fichier", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("kindle-choose-file")

                Text("Rien n'est enregistré avant que vous ne choisissiez les livres à garder. Un livre importé arrive sur votre pile avec son titre et son auteur : c'est tout ce que l'export contient.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number, format: .number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            Text(text).font(.subheadline)
            Spacer(minLength: 0)
        }
    }

    private var picker: some View {
        List {
            ForEach(books) { book in
                Button {
                    toggle(book)
                } label: {
                    row(book)
                }
                .tint(.primary)
                .disabled(book.alreadyInLibrary)
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) { importBar }
    }

    private func row(_ book: KindleBook) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tickSymbol(for: book))
                .font(.title3)
                .foregroundStyle(book.alreadyInLibrary ? Color.secondary : Color.accentColor)
                .accessibilityHidden(true)
            BookCover(book: book.asCoverSubject, width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(book.authorLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if book.alreadyInLibrary {
                Text("Déjà présent")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .opacity(book.alreadyInLibrary ? 0.55 : 1)
    }

    private func tickSymbol(for book: KindleBook) -> String {
        if book.alreadyInLibrary { return "checkmark.circle" }
        return selected.contains(book.key) ? "checkmark.circle.fill" : "circle"
    }

    private var importBar: some View {
        VStack(spacing: 8) {
            Button {
                Task { await importSelected() }
            } label: {
                HStack {
                    Spacer()
                    if isImporting {
                        ProgressView().tint(.white)
                    } else {
                        Text(importLabel)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty || isImporting)
            .accessibilityIdentifier("kindle-import")

            if isImporting {
                // A whole library is one request: it can take a minute, and a
                // silent button reads as a frozen screen.
                Text("Import en cours, gardez l'écran ouvert...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.bar)
    }

    private var importLabel: String {
        selected.isEmpty
            ? String(localized: "Sélectionnez des livres")
            : String(localized: "Importer \(selected.count) livre(s)")
    }

    private func toggle(_ book: KindleBook) {
        if selected.contains(book.key) {
            selected.remove(book.key)
        } else {
            selected.insert(book.key)
        }
    }

    /// Everything not already on the shelf: a reader who opens this wants their
    /// library, and unticking a handful beats ticking three hundred.
    private func selectAll() {
        selected = Set(books.filter { !$0.alreadyInLibrary }.map(\.key))
    }

    private func read(_ result: Result<URL, Error>) async {
        guard case let .success(url) = result else {
            if case let .failure(error) = result { errorMessage = reportError(error) }
            return
        }
        // A file handed over by the Files app lives outside our sandbox and is
        // only readable while the scope is open.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = String(localized: "Ce fichier n'a pas pu être ouvert.")
            return
        }
        // Amazon writes UTF-8; a file opened and saved by a French Excel comes
        // back in Latin-1, and refusing it outright would be unhelpful.
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
        else {
            errorMessage = String(localized: "Ce fichier n'est pas du texte lisible.")
            return
        }

        isReading = true
        defer { isReading = false }
        do {
            let found = try await ImportAPI.readKindleExport(csv: text)
            csv = text
            books = found
            selectAll()
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func importSelected() async {
        guard let csv, !selected.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let imported = try await ImportAPI.importKindleBooks(
                csv: csv,
                keys: Array(selected)
            )
            onImported(imported)
            dismiss()
        } catch {
            errorMessage = reportError(error)
        }
    }
}

#Preview {
    KindleImportView(onImported: { _ in })
}
