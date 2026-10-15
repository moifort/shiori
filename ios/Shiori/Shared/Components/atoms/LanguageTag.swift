import SwiftUI

/// The language of an edition as a small grey tag beside its name — "EN",
/// "JA" — the way a bookshop marks a foreign edition. Spoken as the language's
/// full name, since a screen reader would spell the code out letter by letter.
struct LanguageTag: View {
    let language: BookLanguage

    var body: some View {
        Text(verbatim: language.code)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .fixedSize()
            .accessibilityLabel(Text(language.label))
    }
}

#Preview {
    HStack {
        Text("The Primal Hunter")
        LanguageTag(language: .en)
        LanguageTag(language: .ja)
    }
    .padding()
}
