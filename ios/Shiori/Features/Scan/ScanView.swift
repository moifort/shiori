import SwiftUI

/// The scan flow, presented full screen over the tabs: camera, then a review of
/// what the model proposed, then the library.
///
/// The review step is not a formality. The model reads a cover it has never seen
/// under whatever light the reader had, and this is where a wrong title gets
/// fixed before it becomes a record they live with.
struct ScanView: View {
    /// Where the pass begins: on the camera, on a photo already taken, or on a
    /// title typed as remembered. The camera is what the tab bar opens; the
    /// other two come from the library's add sheet.
    enum Start: Identifiable {
        case camera
        case photo(Data)
        case title(String)
        /// A page shared from Safari or a bookshop app.
        case link(String)

        var id: String {
            switch self {
            case .camera: "camera"
            case let .photo(data): "photo-\(data.count)"
            case let .title(title): "title-\(title)"
            case let .link(link): "link-\(link)"
            }
        }
    }

    var start: Start = .camera
    var onDismiss: () -> Void

    @State private var viewModel = ScanViewModel()
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
            PremiumSheet(trigger: .scanAllowanceSpent)
        }
        .alert(
            "Le scan a échoué",
            isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .task {
            switch start {
            case .camera: break
            case let .photo(data): await scan(imageData: data)
            case let .title(title): await viewModel.lookUp(title: title)
            case let .link(link): await viewModel.lookUp(link: link)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .camera:
            cameraScreen
        case .analyzing:
            ScanAnalyzingPage(coverData: viewModel.capturedCover)
        case .review:
            if let draft = viewModel.draft {
                ScanReviewPage(
                    draft: draft,
                    seriesLabel: viewModel.seriesLabel,
                    isSaving: viewModel.isSaving,
                    onSave: { approved in
                        Task {
                            if await viewModel.save(approved) != nil { onDismiss() }
                        }
                    },
                    onRetake: viewModel.retake
                )
            }
        case .noResult:
            ScanNoResultPage(onRetake: viewModel.retake, onDismiss: onDismiss)
        case .failed:
            ScanFailedPage(
                reason: viewModel.failure,
                onRetry: { Task { await viewModel.retry() } },
                onRetake: viewModel.retake
            )
        }
    }

    private var cameraScreen: some View {
        ZStack {
            CameraView(
                onCapture: { jpeg in Task { await viewModel.capture(jpeg) } },
                shouldCapture: $shouldCapture
            )
            .ignoresSafeArea()

            ViewfinderOverlay()

            VStack {
                Spacer()
                Button { shouldCapture = true } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().fill(.white).padding(6))
                }
                .accessibilityLabel(Text("Scanner la couverture"))
                .accessibilityIdentifier("scan-shutter")
                .padding(.bottom, 48)
            }
        }
        .navigationTitle("Scanner une couverture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// Downscales before sending. The model tiles the image into tokens, so a
    /// full-resolution photo costs several times more for no extra legibility on
    /// a cover.
    private func scan(imageData data: Data) async {
        let jpeg = await Task.detached(priority: .userInitiated) {
            UIImage(data: data)
                .flatMap { $0.resized(maxDimension: 1000).jpegData(compressionQuality: 0.7) }
        }.value
        guard let jpeg else { return }
        await viewModel.capture(jpeg)
    }
}
