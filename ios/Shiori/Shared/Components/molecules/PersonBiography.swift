import SwiftUI

/// A person's biography under their name, on an author's or a narrator's page:
/// three lines, the last fading out where PLUS sits, opened whole on a tap.
struct PersonBiography: View {
    let text: String

    @State private var isWhole = false

    private static var more: Text { Text("PLUS").font(.callout.weight(.bold)) }

    var body: some View {
        Button { withAnimation(.smooth) { isWhole.toggle() } } label: {
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(isWhole ? nil : 3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                // The last line fades out where PLUS sits rather than under a
                // patch of the page's colour: the cover's colours run under it.
                .mask {
                    Color.black
                        .overlay(alignment: .bottomTrailing) {
                            if !isWhole {
                                HStack(spacing: 0) {
                                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                                        .frame(width: 24)
                                    Self.more.opacity(0).padding(.leading, 6).background(.black)
                                }
                                .fixedSize()
                                .blendMode(.destinationOut)
                            }
                        }
                        .compositingGroup()
                }
                .overlay(alignment: .bottomTrailing) {
                    if !isWhole {
                        Self.more.foregroundStyle(.secondary)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// "Américain · 1975", "Française · 1903 – 1987". The year alone rather
    /// than "né en": the word would have to agree with a person the app does
    /// not know the gender of.
    static func origin(nationality: String?, birthYear: Int?, deathYear: Int?) -> String? {
        let years: String? = switch (birthYear, deathYear) {
        case let (born?, died?): "\(String(born)) – \(String(died))"
        case let (born?, nil): String(born)
        default: nil
        }
        let parts = [nationality, years].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    PersonBiography(text: "Comédien français, voix française de Robert Downey Jr. et de Johnny Depp, il prête aussi sa voix à de nombreux livres audio, de Dune à la Horde du Contrevent.")
        .padding()
}
