import SwiftUI

/// The Amis tab without a friend: the reader's avatar among empty places, a
/// line on what sharing gives, the invitation, and what their friends will
/// see of their shelf.
struct FriendsEmptyInvite: View {
    let myShelf: FriendProfile?
    let isInviting: Bool
    let onAction: (FriendsAction) async -> Void

    @Environment(\.accountAvatar) private var avatar
    @Environment(\.accountFirstName) private var firstName

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    place(size: 54, faded: true)
                    place(size: 66, faded: false)
                    AccountAvatarView(avatar: avatar, firstName: firstName, size: 84)
                        .padding(3)
                        .overlay { Circle().strokeBorder(.white, lineWidth: 3) }
                    place(size: 66, faded: false)
                    place(size: 54, faded: true)
                }
                .padding(.top, 24)
                .accessibilityHidden(true)

                Text("Lire, c’est mieux à plusieurs")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 26)
                Text("Invitez un ami : vous verrez ce qu’il lit, ce qu’il a adoré et ce qui l’attend sur sa pile. Il verra vos livres en retour.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                AsyncButton {
                    await onAction(.invite)
                } label: {
                    Label("Inviter un ami", systemImage: "person.badge.plus")
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled(isInviting)
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .environment(\.colorScheme, .dark)
            .frame(maxWidth: .infinity)
            .background(alignment: .top) {
                CoverBackdrop(url: shown.first?.book.coverURL, fadeHeight: 160, ground: Color(.systemBackground))
                    .frame(height: 760)
                    .offset(y: -300)
            }

            if !shown.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    RowHeader(title: "Ce qu’ils verront de vous", style: .inline)
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 13) {
                            ForEach(shown) { book in
                                Button { Task { await onAction(.openMyBook(book)) } } label: {
                                    PosterCover(book: book.book, label: PosterLabel.of(book.book, in: .recent))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(book.book.title))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 34)
            }
        }
        .padding(.bottom, 32)
    }

    /// The reader's shelf as a friend first meets it: what they read now,
    /// what they hearted, what waits; each book once.
    private var shown: [FriendBook] {
        guard let myShelf else { return [] }
        var seen = Set<String>()
        return (myShelf.reading + myShelf.favorites + myShelf.pile)
            .filter { seen.insert($0.id).inserted }
            .prefix(12)
            .map { $0 }
    }

    private func place(size: CGFloat, faded: Bool) -> some View {
        Image(systemName: "plus")
            .font(.system(size: size * 0.28, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(.black.opacity(0.25), in: .circle)
            .overlay {
                Circle().strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            .opacity(faded ? 0.6 : 1)
    }
}

#Preview {
    NavigationStack {
        ScrollView { FriendsEmptyInvite(myShelf: .preview, isInviting: false) { _ in } }
    }
}
