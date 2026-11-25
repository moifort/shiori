import SwiftUI
import UniformTypeIdentifiers

/// The Goodreads import, connected: how to export, the file picked, read and
/// compared, the reader's choices, then the import. From the settings it ends
/// on the progress and the result; from the onboarding it hands the import to
/// the background at once, and the preparation checklist takes over.
struct GoodreadsImportScreen: View {
    enum Mode {
        case settings
        case onboarding
    }

    var mode: Mode = .settings
    /// A file handed over by "Ouvrir dans Shiori", read straight away.
    var file: URL?
    /// Called once the import is started (onboarding) or seen through
    /// (settings), and when the reader leaves without importing.
    var onFinished: (_ started: Bool) -> Void

    @Environment(\.openURL) private var openURL
    @State private var importer = GoodreadsBackgroundImport.shared
    @State private var step: Step = .explain
    @State private var picking = false
    @State private var csv: String?
    @State private var preview: GoodreadsPreview?
    @State private var choices = GoodreadsChoices(preview: GoodreadsPreview(
        rows: [], readCount: 0, readingCount: 0, toReadCount: 0, droppedCount: 0,
        ratedCount: 0, datedCount: 0, reviewedCount: 0
    ))
    @State private var deciding: GoodreadsRow?
    @State private var booksFilter: GoodreadsBooksPage.Filter?

    private enum Step: Equatable {
        case explain
        case reading
        case preview
        case failed(GoodreadsFileError?, String?)
        case importing
    }

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(item: $booksFilter) { filter in
                    if let preview {
                        GoodreadsBooksPage(preview: preview, choices: $choices, filter: filter) { deciding = $0 }
                    }
                }
                .toolbar {
                    if step != .importing {
                        ToolbarItem(placement: .cancellationAction) {
                            ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                                onFinished(false)
                            }
                        }
                    }
                }
        }
        .fileImporter(
            isPresented: $picking,
            allowedContentTypes: [.commaSeparatedText, .plainText, .text]
        ) { result in
            if case let .success(url) = result { read(url) }
        }
        .sheet(item: $deciding) { row in
            GoodreadsSameBookSheet(row: row, onSame: {
                choices.sameBooks.insert(row.key)
                choices.keys.insert(row.key)
                deciding = nil
            }, onDifferent: {
                choices.sameBooks.remove(row.key)
                choices.keys.insert(row.key)
                deciding = nil
            })
        }
        .task {
            if let file, csv == nil { read(file) }
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .explain:
            GoodreadsExplainPage(
                onChooseFile: { picking = true },
                onOpenGoodreads: { openURL(GoodreadsLinks.export) }
            )
        case .reading:
            GoodreadsReadingPage(lines: GoodreadsReadingPage.lines(found: preview, reading: true))
        case .preview:
            if let preview {
                GoodreadsPreviewPage(preview: preview, choices: $choices, isImporting: importer.isRunning) { action in
                    switch action {
                    case let .showBooks(filter): booksFilter = filter
                    case let .decide(row): deciding = row
                    case .importBooks: startImport()
                    }
                }
            }
        case let .failed(reason, message):
            failure(reason, message: message)
        case .importing:
            importing
        }
    }

    @ViewBuilder private var importing: some View {
        if let preview, importer.phase == .finished, let outcome = importer.outcome {
            GoodreadsDonePage(outcome: outcome, preview: preview, choices: choices) {
                importer.reset()
                onFinished(true)
            }
        } else if case let .failed(message) = importer.phase {
            failure(nil, message: message)
        } else {
            let total = choices.importedCount(in: preview ?? .preview)
            GoodreadsProgressPage(
                covers: (preview?.newRows ?? []).prefix(5).map(\.cover),
                done: importer.outcome == nil ? 0 : Int(Double(total) * importer.progress),
                total: total,
                progress: importer.progress,
                onClose: { onFinished(true) }
            )
        }
    }

    private func failure(_ reason: GoodreadsFileError?, message: String?) -> some View {
        let retry = EmptyState.Action("Choisir un autre fichier") { picking = true }
        return Group {
            switch reason {
            case .notGoodreads:
                EmptyState(
                    systemImage: "doc.questionmark",
                    title: "Ce fichier ne vient pas de Goodreads",
                    message: "Choisissez le fichier goodreads_library_export.csv préparé par Goodreads.",
                    primary: retry
                )
            case .empty:
                EmptyState(
                    systemImage: "book",
                    title: "Aucun livre dans ce fichier",
                    message: "Vérifiez que vous étiez connecté au bon compte Goodreads au moment de l'export.",
                    primary: retry
                )
            case .unreadable, nil:
                EmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Import impossible",
                    verbatim: message ?? String(localized: "Le fichier n'a pas pu être lu."),
                    primary: retry
                )
            }
        }
        .navigationTitle("Goodreads")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Read the file, then hand it to the server for the preview.
    private func read(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            step = .failed(.unreadable, nil)
            return
        }
        csv = text
        preview = nil
        withAnimation { step = .reading }
        Task {
            do {
                let found = try await GoodreadsAPI.preview(csv: text)
                preview = found
                choices = GoodreadsChoices(preview: found)
                // Long enough to read each tick.
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation { step = .preview }
            } catch let error as GoodreadsFileError {
                step = .failed(error, nil)
            } catch {
                step = .failed(nil, reportError(error))
            }
        }
    }

    private func startImport() {
        guard let csv else { return }
        importer.start(csv: csv, choices: choices)
        switch mode {
        case .onboarding: onFinished(true)
        case .settings: withAnimation { step = .importing }
        }
    }
}

extension GoodreadsBooksPage.Filter: Identifiable {
    var id: Self { self }
}

#Preview {
    GoodreadsImportScreen(onFinished: { _ in })
        .environment(\.colorScheme, .dark)
}
