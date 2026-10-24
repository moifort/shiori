import PhotosUI
import SwiftUI

/// A shelf in one photo: the camera or a picked photo, the books found, the
/// checklist, then the run that adds them. Beside `ScanScreen` rather than
/// inside it: one book reviewed field by field and thirty ticked in a list
/// share a camera and nothing else.
struct ShelfImportScreen: View {
    enum Start {
        case camera
        case photo(Data)
    }

    var start: Start = .camera
    var onDismiss: () -> Void

    @State private var viewModel: ShelfImportViewModel
    @State private var shouldCapture = false
    @State private var pickedPhoto: PhotosPickerItem?

    init(start: Start = .camera, onDismiss: @escaping () -> Void, client: ScanClient = .live) {
        self.start = start
        self.onDismiss = onDismiss
        _viewModel = State(initialValue: ShelfImportViewModel(client: client))
    }

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
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            pickedPhoto = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                await detect(imageData: data)
            }
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
            ShelfChecklistPage(
                photo: viewModel.photo,
                books: viewModel.books,
                ticked: viewModel.ticked,
                remainingScans: viewModel.remainingScans,
                crop: viewModel.crop(of:)
            ) { action in
                switch action {
                case let .toggle(id): viewModel.toggle(id)
                case let .correct(id, title, authors): viewModel.correct(id, title: title, authors: authors)
                case .addTicked: viewModel.addTicked()
                }
            }
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
            ShelfAddingPage(
                books: viewModel.books,
                progress: viewModel.progress,
                isDone: viewModel.isDone,
                onRetry: viewModel.retryAdding,
                onDone: onDismiss
            )
        }
    }

    /// The viewfinder with the shutter over it; on an unfolded iPhone Duo, the
    /// viewfinder on one page and the controls on the other.
    private var cameraScreen: some View {
        TwoPages {
            viewfinder
        } second: {
            CameraControlsPage(
                title: "Plusieurs livres",
                hint: "Tranches bien lisibles, ou couvertures posées à plat. Jusqu'à 30 livres.",
                shutterLabel: "Photographier les livres",
                shutterIdentifier: "shelf-shutter"
            ) {
                shouldCapture = true
            } accessory: {
                photoPicker
            }
        } single: {
            singlePageCamera
        }
        .background(.black)
        .navigationTitle("Plusieurs livres")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var viewfinder: some View {
        CameraView(
            maxDimension: ShelfImportViewModel.photoDimension,
            onCapture: { jpeg in Task { await viewModel.detect(jpeg) } },
            shouldCapture: $shouldCapture
        )
        .ignoresSafeArea()
        .clipped()
    }

    /// A shelf already photographed, or a friend's.
    private var photoPicker: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images) {
            Image(systemName: "photo.on.rectangle")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.4), in: .circle)
        }
        .accessibilityLabel(Text("Choisir une photo"))
        .accessibilityIdentifier("shelf-library")
    }

    private var singlePageCamera: some View {
        ZStack {
            viewfinder

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
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    photoPicker
                        .padding(.leading, 32)
                }
                .padding(.bottom, 48)
            }
        }
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
