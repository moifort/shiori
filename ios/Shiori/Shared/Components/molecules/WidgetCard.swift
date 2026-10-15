import SwiftUI

/// The rounded card every dashboard widget sits in, titled the way the Fitness
/// app titles its cards. A header with an action gets a chevron and becomes the
/// tap target, so a reader learns which cards lead somewhere.
struct WidgetCard<Content: View, Accessory: View>: View {
    let title: LocalizedStringKey
    var action: (() -> Void)?
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private var header: some View {
        if let action {
            Button(action: action) {
                HStack {
                    titleText
                    Spacer()
                    accessory
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                titleText
                Spacer()
                accessory
            }
        }
    }

    private var titleText: some View {
        Text(title).font(.headline)
    }
}

extension WidgetCard where Accessory == EmptyView {
    init(title: LocalizedStringKey, action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.action = action
        self.accessory = EmptyView()
        self.content = content()
    }
}

#Preview {
    VStack {
        WidgetCard(title: "En cours", action: {}) { Text("Contenu") }
        WidgetCard(title: "Tendances") { Text("Contenu") }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
