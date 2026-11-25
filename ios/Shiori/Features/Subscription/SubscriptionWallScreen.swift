import StoreKit
import SwiftUI

/// The wall in front of the app while the account holds no subscription: there is no free
/// plan. Whether it offers the free month or the plans as they are is the App Store's answer
/// — the account's Apple ID may still start the introductory offer or not — never a guess
/// kept in the app. Buying through it is the same path as anywhere else: the server grants
/// Premium, and the app opens.
struct SubscriptionWallScreen: View {
    @Environment(SubscriptionStore.self) private var store
    @State private var kind: SubscriptionWallPage.Kind = .trial
    @State private var showsAccount = false

    var body: some View {
        SubscriptionWallPage(
            kind: kind,
            offers: offers,
            savings: yearlySavings,
            isLoading: store.isLoading,
            isPurchasing: store.isPurchasing,
            onBuy: { offer in
                guard let product = offer.product else { return }
                await store.purchase(product)
            },
            onRestore: { await store.restore() },
            onAccount: { showsAccount = true }
        )
        .background { CoverVeil(covering: true) }
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showsAccount) {
            NavigationStack { ProfileSettingsScreen() }
        }
        .alert(
            "Achat impossible",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task(id: store.products.map(\.id)) { kind = await eligibility() }
        .onAppear { track(.paywallShown(trigger: "wall")) }
    }

    /// The yearly plan first, the plan put forward.
    private var offers: [PremiumOffer] {
        SubscriptionProducts.all.compactMap { id in
            store.products.first { $0.id == id }.map(PremiumOffer.init)
        }
    }

    /// What the yearly plan saves against twelve months of the monthly one, from the store's
    /// own prices.
    private var yearlySavings: Decimal? {
        guard
            let yearly = offers.first(where: { $0.id == SubscriptionProducts.yearly }),
            let monthly = offers.first(where: { $0.id == SubscriptionProducts.monthly }),
            monthly.price > 0
        else { return nil }
        let savings = (monthly.price * 12 - yearly.price) / (monthly.price * 12)
        return savings > 0 ? savings : nil
    }

    /// The free month while the Apple ID may still start it; the plans as they are after.
    private func eligibility() async -> SubscriptionWallPage.Kind {
        guard let yearly = store.products.first(where: { $0.id == SubscriptionProducts.yearly }),
            let subscription = yearly.subscription,
            subscription.introductoryOffer != nil
        else { return .lapsed }
        return await subscription.isEligibleForIntroOffer ? .trial : .lapsed
    }
}
