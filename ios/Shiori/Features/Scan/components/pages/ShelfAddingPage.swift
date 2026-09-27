import SwiftUI

/// One line per ticked book as it is described and saved. The sheet can be
/// closed at any point: the work belongs to the view model, not this page.
struct ShelfAddingPage: View {
    let viewModel: ShelfImportViewModel
    let onDone: () -> Void

    private var chosen: [DetectedBook] {
        viewModel.books.filter { viewModel.progress[$0.id] != nil }
    }

    var body: some View {
        List(chosen) { book in
            HStack(spacing: 12) {
                icon(for: viewModel.progress[book.id] ?? .waiting)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title ?? "")
                        .lineLimit(2)
                    if case let .failed(reason) = viewModel.progress[book.id] {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if case .failed = viewModel.progress[book.id] {
                    Button("Réessayer") { viewModel.retryAdding(book.id) }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("shelf-retry-\(book.id)")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !viewModel.isDone {
                    Text("Vous pouvez fermer : l'ajout continue et les livres apparaissent dans la bibliothèque.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button(action: onDone) {
                    Text("Voir ma bibliothèque").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("shelf-done")
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Ajout de \(chosen.count) livres")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }

    @ViewBuilder
    private func icon(for progress: ShelfImportViewModel.Progress) -> some View {
        switch progress {
        case .waiting:
            Image(systemName: "clock").foregroundStyle(.secondary)
        case .adding:
            ProgressView()
        case .added:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ShelfAddingPage(viewModel: .preview(step: .adding), onDone: {})
    }
}
#endif
