import SwiftUI

/// A book of an author the reader does not hold, opened from "À découvrir":
/// its cover over its own colours, its title, the author and the year, and
/// the one thing to do with it — put it on the pile.
struct AuthorWorkPage: View {
    let work: AuthorWork
    let author: String
    let isAdding: Bool
    let onAdd: () async -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PosterCover(
                    book: Book(id: "work-\(work.id)", title: work.title, authors: [author], coverURL: work.coverURL, status: .toRead),
                    caption: "",
                    width: 170
                )
                .shadow(color: .black.opacity(0.5), radius: 20, y: 12)
                .padding(.top, 120)
                VStack(spacing: 4) {
                    Text(work.title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                AsyncButton(action: onAdd) {
                    Label("Ajouter à ma pile", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: 260)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(isAdding)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .background(alignment: .top) {
                CoverBackdrop(url: work.coverURL, fadeHeight: 140)
                    .frame(height: 420)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(work.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var subtitle: String {
        guard let year = work.publishedIn else { return author }
        return "\(author) · \(String(year))"
    }
}

#Preview {
    NavigationStack {
        AuthorWorkPage(
            work: AuthorWork(title: "Le Prince bâtard", publishedIn: 2013, coverURL: nil),
            author: "Robin Hobb",
            isAdding: false
        ) {}
    }
}
