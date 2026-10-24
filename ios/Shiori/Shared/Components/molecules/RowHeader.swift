import SwiftUI

/// The title over a row or a block: the name in bold on the leading edge and,
/// on the trailing one, what the row leads to — "tout voir", a count — with a
/// chevron when it opens something. The whole trailing label answers the tap;
/// the title only names. Inline, as the TV app heads its shelves on a phone:
/// the name larger with the chevron right after it, the whole of it the tap.
struct RowHeader: View {
    enum Style {
        /// The detail and its chevron on the trailing edge.
        case trailing
        /// The chevron right after the title, without the detail.
        case inline
    }

    let title: LocalizedStringKey
    /// The trailing label: a count, "tout voir". Nil leaves the title alone.
    var detail: String?
    var style: Style = .trailing
    /// Opens what the row stands for. Nil draws the detail without a chevron.
    var action: (() -> Void)?

    var body: some View {
        switch style {
        case .trailing: trailing
        case .inline: inline
        }
    }

    @ViewBuilder private var inline: some View {
        let name = Text(title)
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
        if let action {
            Button(action: action) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    name
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
        } else {
            name.accessibilityAddTraits(.isHeader)
        }
    }

    private var trailing: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            if let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        if let detail { Text(detail) }
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .imageScale(.small)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            } else if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        RowHeader(title: "En cours", detail: String(localized: "tout voir"), action: {})
        RowHeader(title: "Pile à lire", detail: "18", action: {})
        RowHeader(title: "Ma lecture", detail: String(localized: "lu en \(14) jours"))
        RowHeader(title: "Informations")
        RowHeader(title: "Nouveautés", style: .inline, action: {})
    }
    .padding()
}
