import SwiftUI

/// The title over a row or a block, as the TV app heads its shelves: the name
/// in bold on the leading edge and, on the trailing one, what the row leads to
/// — "tout voir", a count — with a chevron when it opens something. The whole
/// trailing label answers the tap; the title only names.
struct RowHeader: View {
    let title: LocalizedStringKey
    /// The trailing label: a count, "tout voir". Nil leaves the title alone.
    var detail: String?
    /// Opens what the row stands for. Nil draws the detail without a chevron.
    var action: (() -> Void)?

    var body: some View {
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
    }
    .padding()
}
