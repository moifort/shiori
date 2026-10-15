import SwiftUI

/// One entry of the settings list: a tinted badge, a title, and under it a
/// value read at runtime — an email, a version, a store — which the caller
/// localizes since it is data, not a key.
struct SettingsRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: String?
    let tint: Color

    /// The badge box scales with Dynamic Type; the glyph is sized to a fixed
    /// fraction of it, so its inset stays constant at every text size.
    @ScaledMetric(relativeTo: .body) private var iconBadgeSize: CGFloat = 28
    private var glyphSize: CGFloat { iconBadgeSize * 0.5 }

    init(icon: String, title: LocalizedStringKey, subtitle: String? = nil, tint: Color = .accentColor) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: icon)
                .font(.system(size: glyphSize))
                .foregroundStyle(.white)
                .frame(width: iconBadgeSize, height: iconBadgeSize)
                .background(
                    tint,
                    in: RoundedRectangle(cornerRadius: iconBadgeSize * 6 / 28, style: .continuous)
                )
        }
        // A plain button only answers where something is drawn: stretched and
        // shaped, the whole row is the target, not just its title.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

#Preview {
    List {
        SettingsRow(icon: "person.crop.circle.fill", title: "Profil", subtitle: "thibaut@example.com", tint: .blue)
        SettingsRow(icon: "sparkles", title: "Découvrir Premium", tint: .orange)
    }
}
