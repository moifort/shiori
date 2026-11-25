import SwiftUI

/// What a scan refused for want of scans brings up. There is no free plan, so a subscriber
/// is the one who meets it: the month's 30 scans spent, told when the counter starts again,
/// never sold the plan they already hold. An account without Premium, which only a build
/// from before the wall could leave in the app, still gets the offer.
private struct AllowanceSpent: ViewModifier {
    @Binding var isPresented: Bool
    let trigger: PremiumTrigger
    let onDismiss: () -> Void
    @Environment(SubscriptionStore.self) private var store

    private var isSubscriber: Bool { store.isPremium == true }

    func body(content: Content) -> some View {
        content
            .sheet(
                isPresented: Binding(get: { isPresented && !isSubscriber }, set: { isPresented = $0 }),
                onDismiss: onDismiss
            ) {
                PremiumSheet(trigger: trigger)
            }
            .alert(
                "Scans du mois utilisés",
                isPresented: Binding(get: { isPresented && isSubscriber }, set: { isPresented = $0 })
            ) {
                Button("OK", role: .cancel) { onDismiss() }
            } message: {
                Text(message)
            }
    }

    private var message: String {
        guard let renewsOn = store.quota?.renewsOn else {
            return String(localized: "Vos 30 scans du mois sont utilisés. Le compteur repart le mois prochain.")
        }
        let day = renewsOn.formatted(.dateTime.day().month(.wide))
        return String(localized: "Vos 30 scans du mois sont utilisés. Le compteur repart le \(day).")
    }
}

extension View {
    /// The Premium offer for an account without it, the renewal date for a subscriber.
    func allowanceSpent(
        isPresented: Binding<Bool>, trigger: PremiumTrigger, onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(AllowanceSpent(isPresented: isPresented, trigger: trigger, onDismiss: onDismiss))
    }
}
