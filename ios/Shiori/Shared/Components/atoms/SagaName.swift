import SwiftUI

/// A saga's name, with headphones after it when it is the saga heard rather
/// than read. A reader who holds a saga both on Audible and in print follows
/// two sagas under one name — the recordings trail the books — and the glyph
/// is what tells the two rows apart. Takes the font and line limit of where
/// it sits.
struct SagaName: View {
    let name: String
    let isAudio: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(name)
            if isAudio {
                Image(systemName: "headphones")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Livre audio"))
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        SagaName(name: "Bobiverse", isAudio: true).font(.body.weight(.medium))
        SagaName(name: "Bobiverse", isAudio: false).font(.body.weight(.medium))
        SagaName(name: "Bobiverse", isAudio: true).font(.title3.weight(.semibold))
    }
    .padding()
}
