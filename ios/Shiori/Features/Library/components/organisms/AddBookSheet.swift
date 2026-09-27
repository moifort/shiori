import SwiftUI
import UIKit

/// How a book gets in, chosen on this sheet and acted on once it is closed:
/// the camera, the picker and the scanner are presentations of their own and
/// would fight the sheet on its way out.
enum AddBookSource {
    case camera
    case photo(Data)
    case library
    case title(String)
    case manual
}

/// The sheet behind the tab bar's scan button, laid out as Vinarium's file
/// sheet: the camera and the last photos in one strip, ready to tap — a cover
/// shot a minute ago is one tap away instead of a trip through the picker —
/// then the two ways in that need no photo: a title typed as remembered, which
/// the AI looks up, and a record typed by hand.
///
/// A typed title is searched here before the sheet closes: a title that means
/// several books lists them under the field for the reader to pick, so the
/// long lookup that follows runs on the right one.
struct AddBookSheet: View {
    var onCamera: () -> Void = {}
    var onAllPhotos: () -> Void = {}
    var onPickedPhoto: (Data) -> Void = { _ in }
    var onTitle: (String) -> Void = { _ in }
    var onManual: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var recentPhotos = RecentPhotos()
    @State private var loadingPhotoId: String?
    @State private var title = ""
    @FocusState private var titleFocused: Bool
    @State private var search: TitleSearch = .idle

    /// Where the typed title stands, between the arrow and the lookup.
    private enum TitleSearch: Equatable {
        case idle
        case searching
        /// Several books match: the reader picks one.
        case candidates([TitleCandidate])
        case noMatch
        case failed(String)
    }

    /// Scaled with the text: a tile whose label grows while its frame stays
    /// put is a tile whose label gets cut in half.
    @ScaledMetric(relativeTo: .body) private var tileSide: CGFloat = 116
    @ScaledMetric(relativeTo: .title3) private var closeSide: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 60
    private let tileRadius: CGFloat = 16
    private let padding: CGFloat = 20

    /// The sheet asks for exactly what it lays out, so nothing is clipped at a
    /// larger text size. The last term is the home indicator's own room.
    private var sheetHeight: CGFloat {
        padding + closeSide + padding + tileSide + padding + rowHeight + 12 + rowHeight + padding + 34
    }

    /// A list of books does not fit the compact sheet, so while one is shown the
    /// sheet has only its full height to be at, and opens up to it.
    private var detents: Set<PresentationDetent> {
        if case .candidates = search { return [.large] }
        return [.height(sheetHeight), .large]
    }

    /// The camera is offered only where there is one: on a simulator the
    /// scanner would open on a black screen.
    private var hasCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: padding) {
            header
            strip
            titleRow
            searchOutcome
            manualRow
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .task { await recentPhotos.load() }
        // Editing the title makes the answer to the previous one stale.
        .onChange(of: title) { _, _ in
            if search != .searching { search = .idle }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: closeSide, height: closeSide)
                    .background(Color(.secondarySystemBackground), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")
            .accessibilityIdentifier("add-book-close")

            Text("Ajouter un livre")
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Button("Toutes les photos") { onAllPhotos() }
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                .accessibilityIdentifier("add-book-library")
        }
    }

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if hasCamera {
                    cameraTile
                }
                switch recentPhotos.access {
                case .pending:
                    ForEach(0 ..< 3, id: \.self) { _ in placeholderTile }
                case .granted:
                    ForEach(Array(recentPhotos.photos.enumerated()), id: \.element.id) { index, photo in
                        photoTile(photo, at: index)
                    }
                case .denied:
                    permissionTile
                }
            }
        }
        .scrollClipDisabled()
    }

    private var cameraTile: some View {
        Button { onCamera() } label: {
            tileBackground {
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                    Text("Scanner la couverture")
                        .font(.footnote)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }
                .padding(8)
                .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add-book-camera")
    }

    private func photoTile(_ photo: RecentPhotos.Photo, at index: Int) -> some View {
        Button { pick(photo) } label: {
            Image(uiImage: photo.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: tileSide, height: tileSide)
                .clipShape(.rect(cornerRadius: tileRadius))
                .overlay {
                    if loadingPhotoId == photo.id {
                        ZStack {
                            Color.black.opacity(0.35)
                            ProgressView().tint(.white)
                        }
                        .clipShape(.rect(cornerRadius: tileRadius))
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(loadingPhotoId != nil)
        .accessibilityLabel("Photo récente")
        .accessibilityIdentifier("add-book-recent-photo-\(index)")
    }

    /// Without library access there is nothing to lay out, so the tile says so
    /// and leads where the decision is reversed.
    private var permissionTile: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            tileBackground {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    Text("Autoriser les photos")
                        .font(.footnote)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }
                .padding(8)
                .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add-book-photos-permission")
    }

    private var placeholderTile: some View {
        tileBackground { Color.clear }
    }

    private func tileBackground(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(width: tileSide, height: tileSide)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: tileRadius))
    }

    /// A title typed as remembered, which the AI looks up: the same proposal
    /// as a scan, for a book that is not at hand.
    private var titleRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title3)
            TextField("Un titre, l'IA cherche le reste", text: $title)
                .focused($titleFocused)
                .submitLabel(.search)
                .onSubmit(submitTitle)
                .disabled(search == .searching)
                .accessibilityIdentifier("add-book-title")
            if search == .searching {
                ProgressView()
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("Recherche en cours")
                    .accessibilityIdentifier("add-book-title-searching")
            } else if !trimmedTitle.isEmpty {
                Button(action: submitTitle) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rechercher")
                .accessibilityIdentifier("add-book-title-search")
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: rowHeight)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 18))
        .contentShape(.rect)
        .onTapGesture { titleFocused = true }
    }

    /// What the search answered, when it is not a book to open straight away.
    @ViewBuilder
    private var searchOutcome: some View {
        switch search {
        case .idle, .searching:
            EmptyView()
        case let .candidates(candidates):
            candidateList(candidates)
        case .noMatch:
            searchMessage("Aucun livre trouvé, essayez un autre titre", systemImage: "magnifyingglass")
        case let .failed(reason):
            searchMessage(reason, systemImage: "exclamationmark.triangle")
        }
    }

    private func candidateList(_ candidates: [TitleCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plusieurs livres correspondent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                    if index > 0 { Divider().padding(.leading, 16) }
                    candidateRow(candidate, at: index)
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 18))
        }
    }

    private func candidateRow(_ candidate: TitleCandidate, at index: Int) -> some View {
        Button { onTitle(candidate.lookUpQuery) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    if let byline = byline(of: candidate) {
                        Text(byline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let series = candidate.seriesName {
                        Text(candidate.volume.map { "\(series) · Tome \($0)" } ?? series)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add-book-candidate-\(index)")
    }

    /// The authors and the year, the two things that tell two books of the same
    /// name apart.
    private func byline(of candidate: TitleCandidate) -> String? {
        let parts = [
            candidate.authors.isEmpty ? nil : candidate.authors.joined(separator: ", "),
            candidate.firstPublishedIn.map(String.init),
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func searchMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .accessibilityIdentifier("add-book-title-message")
    }

    private var manualRow: some View {
        Button { onManual() } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                Text("Ajouter à la main")
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: rowHeight)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 18))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add-book-manual")
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Searches the typed title while the sheet stays open. One match opens
    /// straight away; several are listed for the reader to pick. A spent
    /// allowance hands the title on as it was, so the scan flow shows the
    /// paywall it already knows how to show.
    private func submitTitle() {
        let typed = trimmedTitle
        guard !typed.isEmpty, search != .searching else { return }
        titleFocused = false
        search = .searching
        Task {
            do {
                let candidates = try await ScanAPI.searchTitle(typed)
                switch candidates.count {
                case 0: search = .noMatch
                case 1:
                    search = .idle
                    onTitle(candidates[0].lookUpQuery)
                default: search = .candidates(candidates)
                }
            } catch let APIError.domain(code, _) where code == "QUOTA_EXHAUSTED" {
                search = .idle
                onTitle(typed)
            } catch {
                search = .failed(reportError(error))
            }
        }
    }

    /// The full-size photo is fetched on the tap and downscaled before it
    /// leaves: the model tiles the image into tokens, so a full-resolution
    /// shot costs several times more for no extra legibility on a cover.
    private func pick(_ photo: RecentPhotos.Photo) {
        loadingPhotoId = photo.id
        Task {
            let image = await recentPhotos.fullImage(id: photo.id)
            let jpeg = image?.resized(maxDimension: 1000).jpegData(compressionQuality: 0.7)
            loadingPhotoId = nil
            guard let jpeg else { return }
            onPickedPhoto(jpeg)
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddBookSheet()
    }
}
