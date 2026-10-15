import SwiftUI

/// The bell in the Découvrir toolbar, which opens the release alerts where
/// the releases are, without a trip to the settings. Struck through while
/// nothing can reach the reader.
struct DiscoverAlertsButton: View {
    let isSilenced: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Notifications", systemImage: isSilenced ? "bell.slash" : "bell")
        }
        .accessibilityIdentifier("discover-alerts")
    }
}

#Preview("Alerts button") {
    HStack(spacing: 24) {
        DiscoverAlertsButton(isSilenced: false) {}
        DiscoverAlertsButton(isSilenced: true) {}
    }
    .labelStyle(.iconOnly)
}
