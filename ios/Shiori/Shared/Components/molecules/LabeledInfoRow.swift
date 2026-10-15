import SwiftUI

struct LabeledInfoRow: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String

    var body: some View {
        Label {
            LabeledContent {
                Text(value)
            } label: {
                Text(title)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
        }
        // Every fact a sheet states can be taken elsewhere with a long press.
        .copyable(value)
    }
}

#Preview {
    List {
        LabeledInfoRow(title: "Appellation", value: "Margaux", icon: "seal")
        LabeledInfoRow(title: "R\u{00E9}gion", value: "Bordeaux", icon: "map")
    }
}
