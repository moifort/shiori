import SwiftUI

/// One entry of the settings list: a grey badge, a title, and under it a
/// value read at runtime — an email, a version, a store — which the caller
/// localizes since it is data, not a key.
struct SettingsRow: View {
    let icon: String
    /// A logo of the asset catalogue drawn in place of `icon`.
    private var logo: String?
    let title: LocalizedStringKey
    let subtitle: String?

    /// The badge box scales with Dynamic Type; the glyph is sized to a fixed
    /// fraction of it, so its inset stays constant at every text size.
    @ScaledMetric(relativeTo: .body) private var iconBadgeSize: CGFloat = 28
    private var glyphSize: CGFloat { iconBadgeSize * 0.5 }

    init(icon: String, title: LocalizedStringKey, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    /// A row for a service, its logo in the badge.
    init(logo: String, title: LocalizedStringKey, subtitle: String? = nil) {
        self.init(icon: "", title: title, subtitle: subtitle)
        self.logo = logo
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
            glyph
                .font(.system(size: glyphSize))
                // Monochrome like every icon: the glyph in the text's colour.
                .foregroundStyle(.primary)
                .frame(width: iconBadgeSize, height: iconBadgeSize)
                .background(
                    Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: iconBadgeSize * 6 / 28, style: .continuous)
                )
        }
        // A plain button only answers where something is drawn: stretched and
        // shaped, the whole row is the target, not just its title.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    @ViewBuilder private var glyph: some View {
        if let logo {
            Image(logo)
                .resizable()
                .scaledToFit()
                .frame(width: glyphSize * 1.2, height: glyphSize * 1.2)
        } else {
            Image(systemName: icon)
        }
    }
}

#Preview {
    List {
        SettingsRow(icon: "person.crop.circle.fill", title: "Profil", subtitle: "thibaut@example.com")
        SettingsRow(icon: "sparkles", title: "Découvrir Premium")
    }
}
