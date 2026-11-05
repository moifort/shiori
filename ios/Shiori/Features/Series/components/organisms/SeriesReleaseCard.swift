import SwiftUI

/// The next volume of a saga announced, drawn as the home's "En cours" lead
/// card: its cover edge to edge on the leading side, over the cover's own
/// colours the title, the author and the volume's place at the top, and at
/// the foot one white button that orders it from the store — Audible for a recording, Amazon
/// otherwise. Under the title, side by side, the outlined tags: how long is
/// left, "Audio" for a recording, the language when it is not the phone's, and
/// the binoculars for an edition awaited; nothing on the cover. The day itself sits
/// in the corner as a white calendar leaf on glass. A tap elsewhere opens the
/// volume's page, as on Découvrir. No "wait for it": the saga's bell already
/// alerts on the day.
struct SeriesReleaseCard: View {
    let volume: DiscoveredVolume
    let author: String
    let isAudio: Bool
    /// The line over the title, in place of the author and the volume's place:
    /// an edition awaited outside any saga names its author and format.
    var place: String?
    /// The edition's language: tagged only when it is not the phone's.
    var language: BookLanguage?
    /// An edition the reader waits for: the binoculars among the tags.
    var isAwaited = false
    let onOpen: () -> Void

    /// The card's height: every card of a rail stands as tall, as the home's
    /// "En cours" cards do — two lines of title, and the room of the tags and
    /// of the button kept when a volume has neither. As tall as the cover, so
    /// the cover shows whole.
    private static let height: CGFloat = 150
    /// A cover's 2:3 at the card's height: whole, not cropped. It grows, cropped
    /// at its foot, only when larger text makes the card taller.
    private static let coverHeight: CGFloat = 150
    private static let coverWidth: CGFloat = 100
    /// The calendar leaf's width and its margin, kept clear by the text.
    private static let leafRoom: CGFloat = 48
    /// Between a rail of these cards and the header over it — "À venir",
    /// "Prochaines sorties": more than a shelf's, so the title does not sit
    /// against the card.
    static let headerSpacing: CGFloat = 18

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // The cover runs the card's full height, cropped at its foot
            // rather than letterboxed.
            Color.clear
                .frame(width: Self.coverWidth)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) {
                    BookCover(
                        book: book,
                        width: Self.coverWidth,
                        showsFormatBadge: false,
                        minHeight: Self.coverHeight,
                        cornerRadius: 0
                    )
                }
                .clipped()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                // At the card's top, clear of the calendar leaf in its corner:
                // the author and the volume's place over the title, as the
                // book hero names the saga over the book.
                Text(verbatim: place ?? "\(author) · \(String(localized: "Tome \(volume.number)"))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .padding(.trailing, volume.date == nil ? 0 : Self.leafRoom)
                Text(volume.title)
                    .font(.headline)
                    .lineLimit(2)
                    .padding(.trailing, volume.date == nil ? 0 : Self.leafRoom)
                // The tags side by side under the title. A volume with none
                // keeps their room.
                ZStack(alignment: .leading) {
                    OutlinedTag(text: "0", isFrosted: false).hidden()
                    tags
                }
                .padding(.top, 3)
                Spacer(minLength: 8)
                // The next step at the card's foot; with no store, its room.
                ZStack(alignment: .leading) {
                    preorderButton((URL(string: "https://www.amazon.fr")!, "amazon-logo"))
                        .hidden()
                        .accessibilityHidden(true)
                    if let store {
                        preorderButton(store)
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .frame(minHeight: Self.height)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture(perform: onOpen)
        .overlay(alignment: .topTrailing) {
            if let date = volume.date {
                ReleaseDateBadge(date: date, onGlass: true)
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

    private var tags: some View {
        HStack(spacing: 6) {
            if let countdown = volume.date.flatMap({ ReleaseDateText.countdown($0) }) {
                OutlinedTag(text: countdown, isFrosted: false)
            }
            if isAudio {
                OutlinedTag(text: String(localized: "Audio"), isFrosted: false)
            }
            if let language, language.isForeign {
                OutlinedTag(text: language.code, isFrosted: false)
                    .accessibilityLabel(Text(language.label))
            }
            if isAwaited {
                Image(systemName: "binoculars")
                    .font(.footnote.weight(.semibold))
                    .accessibilityLabel(Text("Suivi"))
            }
        }
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
        let tag = "polyforms09-21"
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
