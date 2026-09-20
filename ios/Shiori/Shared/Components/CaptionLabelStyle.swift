import SwiftUI

/// A label sized for a caption: a small glyph in a narrow column of fixed width,
/// so that two of them stacked keep their words on the same left edge whatever
/// the glyphs' own widths. For text that sits inside a row rather than being the
/// row — beside a cover, under a title — where a list's default label style would
/// hand each icon the wide, centred column meant for a row of its own.
struct CaptionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            configuration.icon
                .imageScale(.small)
                .frame(width: 14)
            configuration.title
        }
    }
}

extension LabelStyle where Self == CaptionLabelStyle {
    static var caption: CaptionLabelStyle { CaptionLabelStyle() }
}

#Preview {
    List {
        VStack(alignment: .leading, spacing: 2) {
            Label("Lu par Thibault de Montalembert", systemImage: "waveform")
            Label("14 h 32", systemImage: "clock")
        }
        .labelStyle(.caption)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
