import SwiftUI

/// The feed's spotlight: an author the reader holds announces a book. Their
/// portrait, what they announce, and the cover with its date over a blur of
/// itself. Without a title the announcement says so and the cover is a "?".
struct AuthorAnnouncementCard: View {
    let release: UpcomingRelease
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        portrait
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.75))
                            Text(release.author?.name ?? release.authors.first ?? "")
                                .font(.title3.weight(.heavy))
                                .lineLimit(2)
                        }
                        lines
                    }
                    Spacer(minLength: 0)
                    cover
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { backdrop }
            .frame(height: 236)
            .foregroundStyle(.white)
            .clipShape(.rect(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.16)) }
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .accessibilityIdentifier("news-author-card")
    }

    private var label: String {
        release.author?.favorite == true ? String(localized: "Auteur favori") : String(localized: "Auteur")
    }

    @ViewBuilder
    private var lines: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(release.volume == nil && release.seriesName == nil
                ? String(localized: "Nouveau livre annoncé")
                : String(localized: "Nouveau tome annoncé"))
            if let title = release.title {
                Text(title).fontWeight(.bold)
            } else {
                Text("Sans titre").fontWeight(.bold)
            }
            if let line = release.seriesLine { Text(line) }
        }
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.9))
        .multilineTextAlignment(.leading)
    }

    private var portrait: some View {
        let name = release.author?.name ?? release.authors.first ?? ""
        return Group {
            if let url = release.author?.portraitURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    FriendMonogram(name: name, size: 64)
                }
                .frame(width: 64, height: 64)
                .clipShape(.circle)
            } else {
                FriendMonogram(name: name, size: 64)
            }
        }
    }

    private var cover: some View {
        BookCover(book: release.cover, width: 110, showsFormatBadge: true)
            .overlay(alignment: .bottom) {
                if let date = release.date {
                    Text(Self.shortDate(date))
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial.opacity(0.9), in: .rect(bottomLeadingRadius: 8, bottomTrailingRadius: 8))
                }
            }
    }

    private var backdrop: some View {
        ZStack {
            Color(white: 0.16)
            if let url = release.coverURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill().blur(radius: 26).saturation(1.3)
                } placeholder: {
                    Color.clear
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                Color.black.opacity(0.35)
            }
        }
    }

    /// "18 déc.": the day and month, or the month, or the year, as announced.
    static func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents(year: parts.first, month: parts.count > 1 ? parts[1] : 1, day: parts.count > 2 ? parts[2] : 1)
        components.hour = 12
        guard let day = Calendar.current.date(from: components) else { return date }
        switch parts.count {
        case 3: return day.formatted(.dateTime.day().month(.abbreviated))
        case 2: return day.formatted(.dateTime.month(.wide).year())
        default: return String(date.prefix(4))
        }
    }
}

#Preview("Author announcement") {
    AuthorAnnouncementCard(release: .authorPreview) {}
        .preferredColorScheme(.dark)
}

#Preview("Author announcement, no title") {
    AuthorAnnouncementCard(release: UpcomingRelease.previews.last ?? .authorPreview) {}
        .preferredColorScheme(.dark)
}
