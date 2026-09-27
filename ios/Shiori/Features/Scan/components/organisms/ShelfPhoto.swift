import SwiftUI

/// The reader's photo with a frame on every book found. The highlighted one
/// is the row the reader last touched, so a spine and its line are easy to
/// match up.
struct ShelfPhoto: View {
    let photo: UIImage
    let books: [DetectedBook]
    var highlighted: Int?

    var body: some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    ForEach(books) { book in
                        let isHighlighted = book.id == highlighted
                        Rectangle()
                            .strokeBorder(isHighlighted ? Color.yellow : Color.green, lineWidth: isHighlighted ? 3 : 1.5)
                            .frame(width: book.box.width * proxy.size.width, height: book.box.height * proxy.size.height)
                            .position(x: book.box.midX * proxy.size.width, y: book.box.midY * proxy.size.height)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}
