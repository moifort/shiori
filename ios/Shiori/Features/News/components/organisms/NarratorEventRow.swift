import SwiftUI

/// A narrator lending their voice to a book: their monogram marked with a
/// microphone, the sentence, the cover and the "+".
struct NarratorEventRow: View {
    let news: NarratorNews
    let onOpen: () -> Void
    let onAdd: () async -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    FriendMonogram(name: news.narrator, size: 44)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 9, weight: .bold))
                                .frame(width: 20, height: 20)
                                .background(.regularMaterial, in: .circle)
                                .overlay { Circle().strokeBorder(Color(.systemBackground), lineWidth: 1.5) }
                                .offset(x: 3, y: 3)
                                .accessibilityLabel("Narrateur")
                        }
                    Text("**\(news.narrator)** prête sa voix à **\(news.title)**")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    BookCover(book: news.cover, width: 46)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            AsyncButton(action: onAdd) {
                Image(systemName: "plus").font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

#Preview("Narrator row") {
    NarratorEventRow(news: .preview, onOpen: {}, onAdd: {})
        .preferredColorScheme(.dark)
}
