import SwiftUI

/// The title playing, over the tab bar on every page: its cover, its title and,
/// with room, the chapter and the time left, pause and +30 s. When the bar
/// folds away on a scroll, the system slides it between the active tab and the
/// scan button, and it keeps the cover, the title and pause.
///
/// The system draws the glass; this draws what sits on it.
struct PlayerAccessory: View {
    struct Item: Hashable {
        let title: String
        /// "Chapitre 12 · 11h47 restantes", or why it does not play.
        let line: String?
        let coverURL: URL?
        let isPlaying: Bool
        let isLoading: Bool
    }

    let item: Item
    let onOpen: () -> Void
    let onTogglePlay: () -> Void
    let onSkipForward: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var isInline: Bool { placement == .inline }

    var body: some View {
        HStack(spacing: isInline ? 10 : 11) {
            Button(action: onOpen) {
                HStack(spacing: isInline ? 10 : 11) {
                    PlayerArtwork(url: item.coverURL, size: isInline ? 30 : 40, cornerRadius: isInline ? 6 : 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if !isInline, let line = item.line {
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(item.title))
            .accessibilityHint(Text("Ouvre le lecteur"))

            Button(action: onTogglePlay) {
                Group {
                    if item.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: item.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: isInline ? 18 : 20))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 40, height: 40)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(item.isLoading)
            .accessibilityLabel(Text(item.isPlaying ? "Pause" : "Lecture"))

            if !isInline {
                Button(action: onSkipForward) {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(item.isLoading)
                .accessibilityLabel(Text("Avancer de 30 secondes"))
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, isInline ? 4 : 8)
    }
}

extension PlayerAccessory.Item {
    static let preview = PlayerAccessory.Item(
        title: ListeningTitle.preview.title,
        line: ListeningText.accessoryLine(.preview),
        coverURL: ListeningTitle.preview.coverURL,
        isPlaying: true,
        isLoading: false
    )
}

#Preview("Over the tab bar") {
    TabView {
        Tab("Accueil", systemImage: "house.fill") {
            List(0..<40) { Text("Ligne \($0)") }
        }
        Tab("Bibliothèque", systemImage: "books.vertical.fill") { Color.clear }
    }
    .tabBarMinimizeBehavior(.onScrollDown)
    .tabViewBottomAccessory {
        PlayerAccessory(item: .preview, onOpen: {}, onTogglePlay: {}, onSkipForward: {})
    }
}
