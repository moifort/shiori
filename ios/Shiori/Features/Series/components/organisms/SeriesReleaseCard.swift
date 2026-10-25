import SwiftUI

/// The next volume of a saga announced, drawn as the home's "En cours" lead
/// card: its cover edge to edge on the leading side, over the cover's own
/// colours the title, the author and the volume's place at the top, and at
/// the foot one white button that orders it from the store — Audible for a recording, Amazon
/// otherwise. Under the title, how long is left before it comes out; the day itself sits
/// in the corner as the iOS Calendar icon. A tap elsewhere opens the
/// volume's page, as on Découvrir. No "wait for it": the saga's bell already
/// alerts on the day.
struct SeriesReleaseCard: View {
    let volume: DiscoveredVolume
    let author: String
    let isAudio: Bool
    let onOpen: () -> Void

    private static let height: CGFloat = 124
    private static let coverWidth: CGFloat = 82
    /// The calendar icon's width and its margin, kept clear by the text.
    private static let leafRoom: CGFloat = 56

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            BookCover(
                book: book,
                width: Self.coverWidth,
                showsFormatBadge: false,
                minHeight: Self.height,
                cornerRadius: 0
            )
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                // At the card's top, clear of the calendar leaf in its corner:
                // the author and the volume's place over the title, as the
                // book hero names the saga over the book.
                Text(verbatim: "\(author) · \(String(localized: "Tome \(volume.number)"))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .padding(.trailing, volume.date == nil ? 0 : Self.leafRoom)
                Text(volume.title)
                    .font(.headline)
                    .lineLimit(2)
                    .padding(.trailing, volume.date == nil ? 0 : Self.leafRoom)
                // How long is left, under the title as its subtitle.
                if let countdown = volume.date.flatMap({ ReleaseDateText.countdown($0) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(countdown)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .padding(.top, 2)
                        .padding(.trailing, Self.leafRoom)
                }
                Spacer(minLength: 0)
                // The next step at the card's foot.
                if let store {
                    preorderButton(store)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture(perform: onOpen)
        .overlay(alignment: .topTrailing) {
            if let date = volume.date {
                ReleaseCalendarIcon(date: date, size: 46)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                    .padding(10)
            }
        }
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: volume.coverURL, ground: .clear)
        }
        .clipShape(.rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("series-releases")
    }

    private var book: Book {
        Book(
            id: "release-\(volume.number)",
            title: volume.title,
            authors: [author],
            format: isAudio ? .audiobook : .book,
            coverURL: volume.coverURL,
            status: .toRead
        )
    }

    private func preorderButton(_ store: (url: URL, logo: String)) -> some View {
        Link(destination: store.url) {
            HStack(spacing: 6) {
                Text("Précommander")
                Image(store.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 12)
                    .accessibilityHidden(true)
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
        }
        .buttonStyle(.glassProminent)
        .tint(.white)
        .foregroundStyle(.black)
        .controlSize(.small)
        .accessibilityIdentifier("series-release-preorder")
    }

    /// Where the volume is ordered: its recording on Audible for a saga
    /// heard, once Audible confirmed it; Amazon for anything else.
    private var store: (url: URL, logo: String)? {
        if isAudio {
            return volume.audibleURL.map { ($0, "audible-logo") }
        }
        return volume.amazonURL(author: author).map { ($0, "amazon-logo") }
    }
}

extension DiscoveredVolume {
    /// Where the volume can be ordered on amazon.fr, tagged, as the server's
    /// `amazonUrlOf` builds a book's: the printed edition's page when its
    /// ISBN has an ISBN-10, else a search on its title and author among books.
    func amazonURL(author: String) -> URL? {
        let tag = "polyforms-21"
        if let isbn13, let isbn10 = Self.isbn10(of: isbn13) {
            return URL(string: "https://www.amazon.fr/dp/\(isbn10)?tag=\(tag)")
        }
        var components = URLComponents(string: "https://www.amazon.fr/s")
        components?.queryItems = [
            URLQueryItem(name: "k", value: [title, author].filter { !$0.isEmpty }.joined(separator: " ")),
            URLQueryItem(name: "i", value: "stripbooks"),
            URLQueryItem(name: "tag", value: tag),
        ]
        return components?.url
    }

    /// A 979 ISBN has no ISBN-10, the form Amazon's product pages answer to.
    private static func isbn10(of isbn13: String) -> String? {
        guard isbn13.count == 13, isbn13.hasPrefix("978") else { return nil }
        let body = isbn13.dropFirst(3).prefix(9)
        let digits = body.compactMap { $0.wholeNumberValue }
        guard digits.count == 9 else { return nil }
        let sum = digits.enumerated().reduce(0) { $0 + $1.element * (10 - $1.offset) }
        let check = (11 - sum % 11) % 11
        return String(body) + (check == 10 ? "X" : String(check))
    }
}

#Preview {
    SeriesReleaseCard(
        volume: DiscoveredVolume(
            number: 7,
            title: "Red God",
            date: Calendar.current.date(byAdding: .day, value: 10, to: .now)!
                .formatted(.iso8601.year().month().day()),
            isbn13: "9782017227311",
            coverURL: nil
        ),
        author: "Pierce Brown",
        isAudio: false
    ) {}
    .padding()
}
