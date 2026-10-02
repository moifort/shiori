import SwiftUI

/// Where the reader holds a book, one switch per medium: paper, screen, or
/// both — one book either way. The last switch on cannot be turned off, since a
/// read book is held somewhere; a recording shows none of this.
struct MediaToggles: View {
    @Binding var media: [BookMedium]

    var body: some View {
        ForEach(BookMedium.allCases) { medium in
            Toggle(isOn: held(medium)) {
                Label(medium.label, systemImage: medium.symbol)
            }
            .disabled(media == [medium])
            .accessibilityIdentifier("media-\(medium.rawValue)")
        }
    }

    private func held(_ medium: BookMedium) -> Binding<Bool> {
        Binding(
            get: { media.contains(medium) },
            set: { isHeld in
                let kept = isHeld ? media + [medium] : media.filter { $0 != medium }
                media = BookMedium.allCases.filter(kept.contains)
            }
        )
    }
}

#Preview {
    @Previewable @State var media: [BookMedium] = [.print]
    Form {
        Section { MediaToggles(media: $media) }
    }
}
