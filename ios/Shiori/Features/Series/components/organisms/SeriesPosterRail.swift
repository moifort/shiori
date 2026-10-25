import SwiftUI

/// A saga's volumes as a row of posters under a header, as the book page draws
/// its saga: each cover with its number in the blurred foot, the volume to
/// read next ringed in white, the row opening centred on it, deep in a long
/// saga too. What each poster is and does is the page's to say.
struct SeriesPosterRail<Item: Identifiable, Poster: View>: View where Item.ID == String {
    let title: LocalizedStringKey
    let items: [Item]
    /// The poster ringed and scrolled to, if any.
    var ringedId: String?
    @ViewBuilder let poster: (Item) -> Poster

    @State private var position = ScrollPosition(idType: String.self)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: title)
            ScrollView(.horizontal) {
                // Lazy: a long saga runs to a hundred volumes or more.
                LazyHStack(alignment: .top, spacing: 13) {
                    ForEach(items) { item in
                        poster(item)
                            .overlay {
                                if item.id == ringedId {
                                    RoundedRectangle(cornerRadius: PosterCover.cornerRadius + 3, style: .continuous)
                                        .strokeBorder(.primary, lineWidth: 2)
                                        .padding(-4)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }
                .scrollTargetLayout()
                // Room for the ring around the volume to read next.
                .padding(6)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .padding(-6)
            .scrollPosition($position, anchor: .center)
            .onChange(of: items.map(\.id), initial: true) {
                if let ringedId { position.scrollTo(id: ringedId, anchor: .center) }
            }
        }
    }
}
