import SwiftUI

/// "Sorties | Amis" under the title: the pills' colours on one capsule, and a
/// dot on Amis while a friend moved since the reader last looked.
struct NewsTabPicker: View {
    let selected: NewsTab
    let friendsHaveNews: Bool
    let onSelect: (NewsTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NewsTab.allCases) { tab in
                let isOn = tab == selected
                Button { onSelect(tab) } label: {
                    HStack(spacing: 6) {
                        Text(tab.label)
                        if tab == .friends, friendsHaveNews {
                            Circle().frame(width: 6, height: 6).accessibilityLabel("Nouveau")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .foregroundStyle(isOn ? Color(.systemBackground) : .primary)
                    .background(isOn ? Color.primary : .clear, in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("news-tab-\(tab.rawValue)")
            }
        }
        .padding(3)
        .background(Color(.secondarySystemGroupedBackground), in: .capsule)
        .animation(.snappy(duration: 0.2), value: selected)
    }
}

#Preview("Tab picker") {
    VStack(spacing: 20) {
        NewsTabPicker(selected: .releases, friendsHaveNews: true) { _ in }
        NewsTabPicker(selected: .friends, friendsHaveNews: false) { _ in }
    }
    .padding(20)
    .preferredColorScheme(.dark)
}
