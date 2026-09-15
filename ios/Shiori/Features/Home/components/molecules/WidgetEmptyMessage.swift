import SwiftUI

/// What a widget shows in place of figures it does not have yet. Every card is
/// drawn from the first book on, so the reader sees what the dashboard will
/// hold; the message says what fills it.
struct WidgetEmptyMessage: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("widget-empty")
    }
}

#Preview {
    WidgetCard(title: "En cours") {
        WidgetEmptyMessage(text: "Aucun livre en cours de lecture.")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
