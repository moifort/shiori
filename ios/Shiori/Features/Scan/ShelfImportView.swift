import SwiftUI

/// A shelf in one photo: the camera or a picked photo, the books found, the
/// checklist, then the run that adds them. Beside `ScanView` rather than
/// inside it: one book reviewed field by field and thirty ticked in a list
/// share a camera and nothing else.
struct ShelfImportView: View {
    enum Start {
        case camera
        case photo(Data)
    }

    var start: Start = .camera
    var onDismiss: () -> Void

    @State private var viewModel = ShelfImportViewModel()
    @State private var shouldCapture = false

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel, action: onDismiss)
                    }
                }
        }
        .sheet(isPresented: $viewModel.paywallShown, onDismiss: onDismiss) {
            PremiumSheet(trigger: .shelfImport)
        }
        .task {
            if case let .photo(data) = start { await detect(imageData: data) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .camera:
            cameraScreen
        case .detecting:
            ShelfDetectingPage(photo: viewModel.photo)
        case .checklist:
            ShelfChecklistPage(viewModel: viewModel)
        case .noResult:
            ScanNoResultPage(
                hint: "Photographiez les tranches de face, bien éclairées, ou posez les couvertures à plat sans qu'elles se chevauchent. Rien n'a été décompté.",
                onRetake: viewModel.retake,
                onDismiss: onDismiss
            )
        case .failed:
            ScanFailedPage(
                reason: viewModel.failure,
                onRetry: { Task { await viewModel.retry() } },
                onRetake: viewModel.retake
            )
        case .adding:
            ShelfAddingPage(viewModel: viewModel, onDone: onDismiss)
        }
    }

    private var cameraScreen: some View {
        ZStack {
            CameraView(
                maxDimension: ShelfImportViewModel.photoDimension,
                onCapture: { jpeg in Task { await viewModel.detect(jpeg) } },
                shouldCapture: $shouldCapture
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()
                Text("Tranches bien lisibles, ou couvertures posées à plat. Jusqu'à 30 livres.")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.4), in: .capsule)
                    .padding(.horizontal, 24)
                Button { shouldCapture = true } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().fill(.white).padding(6))
                }
                .accessibilityLabel(Text("Photographier les livres"))
                .accessibilityIdentifier("shelf-shutter")
                .padding(.bottom, 48)
            }
        }
        .navigationTitle("Plusieurs livres")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// A picked photo is downscaled as the camera's own shot is, to the size
    /// a spine's title stays legible at.
    private func detect(imageData data: Data) async {
        let dimension = ShelfImportViewModel.photoDimension
        let jpeg = await Task.detached(priority: .userInitiated) {
            UIImage(data: data).flatMap { $0.resized(maxDimension: dimension).jpegData(compressionQuality: 0.7) }
        }.value
        guard let jpeg else { return }
        await viewModel.detect(jpeg)
    }
}
