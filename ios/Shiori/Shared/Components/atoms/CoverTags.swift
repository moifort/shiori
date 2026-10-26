import SwiftUI

/// What a cover's top corner says about the edition, in outlined tags as the
/// TV app tags a film "4K CC": its language when it is not the phone's ("EN"),
/// then "Audio" for a recording. Nothing at all for a book in the phone's
/// language on paper, which is what a book is taken to be.
struct CoverTags: View {
    let language: BookLanguage?
    let isAudio: Bool
    /// Frosted glass behind each word, for a cover whose print would fight it.
    var isFrosted = true

    init(language: BookLanguage?, isAudio: Bool, isFrosted: Bool = true) {
        self.language = language
        self.isAudio = isAudio
        self.isFrosted = isFrosted
    }

    init(book: Book, isFrosted: Bool = true) {
        self.init(language: book.language, isAudio: book.format == .audiobook, isFrosted: isFrosted)
    }

    var body: some View {
        HStack(spacing: 4) {
            if let language, language.isForeign {
                OutlinedTag(text: language.code, isFrosted: isFrosted)
                    .accessibilityLabel(Text(language.label))
            }
            if isAudio {
                OutlinedTag(text: String(localized: "Audio"), isFrosted: isFrosted)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        CoverTags(language: .en, isAudio: true)
        CoverTags(language: .ja, isAudio: false)
        CoverTags(language: .fr, isAudio: true)
    }
    .padding()
    .background(.gray)
}
