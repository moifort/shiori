import StoreKit
import SwiftUI

/// Why the sheet came up. Only the headline changes: the offer is the same
/// whether it was reached from the settings or by running out of scans.
enum PremiumTrigger {
    case scanAllowanceSpent
    case discover

    var title: String {
        switch self {
        case .scanAllowanceSpent: return String(localized: "Scans épuisés")
        case .discover: return String(localized: "Shiori Premium")
        }
    }

    /// What GA4 reads to tell the paywall that sells from the one that consoles.
    var analyticsName: String {
        switch self {
        case .scanAllowanceSpent: return "scan_allowance_spent"
        case .discover: return "discover"
        }
    }

    var message: String {
        switch self {
        case .scanAllowanceSpent:
            // Not "this month": the granted scans run out on their own schedule,
            // and this is shown once nothing is left anywhere.
            return String(localized: "Tous vos scans ont été utilisés. Passez en Premium pour scanner sans limite.")
        case .discover:
            return String(localized: "Photographiez une couverture : le livre rejoint votre bibliothèque avec son résumé et sa série. Passez en Premium pour scanner sans limite.")
        }
    }
}

/// The offer, with its prices read from the App Store rather than written here.
/// Carries what App Review requires: a visible restore button, the terms and the
/// privacy policy.
struct PremiumSheet: View {
    let trigger: PremiumTrigger
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    allowance
                    benefits
                    offers
                    legal
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { track(.paywallShown(trigger: trigger.analyticsName)) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
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
        }
        .task { await store.refresh() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(trigger.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(trigger.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// What the free allowance stands at right now, so the offer below argues
    /// from the account's own numbers rather than in the abstract. Nothing is
    /// shown to a subscriber, whose scanning is sold as unlimited, and nothing
    /// when the reading failed: the sheet must still sell without it.
    @ViewBuilder
    private var allowance: some View {
        if let quota = store.quota {
            if !quota.isPremium {
                QuotaGauge(
                    used: quota.used,
                    limit: quota.limit,
                    welcomeRemaining: quota.welcomeRemaining,
                    renewsOn: quota.renewsOn
                )
            }
        } else if store.isLoading {
            // Placeholder numbers, redacted: the network read is visible and the
            // layout does not jump once the real ones land.
            QuotaGauge(used: 0, limit: 5, renewsOn: Date())
                .redacted(reason: .placeholder)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            BenefitRow(icon: "camera.viewfinder", text: "Scans illimités")
            BenefitRow(
                icon: "square.stack",
                text: "Le catalogue complet de vos séries, tomes à paraître compris"
            )
            BenefitRow(icon: "heart", text: "Soutenez l’application pour qu’elle puisse s’autofinancer")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var offers: some View {
        if store.isLoading && store.products.isEmpty {
            LoadingStateView()
                .frame(height: 120)
        } else if store.products.isEmpty {
            Text("Les offres ne sont pas disponibles pour le moment.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 12) {
                // Yearly first: it is the offer put forward.
                ForEach(sortedProducts, id: \.id) { product in
                    OfferButton(
                        product: product,
                        savings: product.id == SubscriptionProducts.yearly ? yearlySavings : nil,
                        isPurchasing: store.isPurchasing
                    ) {
                        if await store.purchase(product) { dismiss() }
                    }
                }
            }
        }
    }

    /// The order the products are declared in, not whatever the App Store returns.
    private var sortedProducts: [Product] {
        SubscriptionProducts.all.compactMap { id in store.products.first { $0.id == id } }
    }

    /// What the yearly plan saves against twelve months of the monthly plan,
    /// computed from the store's own prices so the label can never contradict
    /// them. Nil while either product is missing, or if the yearly plan does
    /// not actually save anything.
    private var yearlySavings: Decimal? {
        guard
            let yearly = store.products.first(where: { $0.id == SubscriptionProducts.yearly }),
            let monthly = store.products.first(where: { $0.id == SubscriptionProducts.monthly }),
            monthly.price > 0
        else { return nil }
        let twelveMonths = monthly.price * 12
        let savings = (twelveMonths - yearly.price) / twelveMonths
        return savings > 0 ? savings : nil
    }

    private var legal: some View {
        VStack(spacing: 12) {
            Button("Restaurer mes achats") {
                Task { await store.restore() }
            }
            .font(.footnote)
            .disabled(store.isPurchasing)

            Text("L’abonnement se renouvelle automatiquement sauf résiliation au moins 24 heures avant la fin de la période en cours. La gestion et la résiliation se font dans les réglages du compte App Store.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Conditions d’utilisation", destination: SubscriptionLinks.terms)
                Link("Confidentialité", destination: SubscriptionLinks.privacy)
            }
            .font(.caption2)
        }
    }
}

/// The two pages App Review requires a paywall to link to. Both must actually
/// answer: guideline 3.1.2 asks for a *functional* link, and the privacy policy
/// is the GitHub Pages site declared as the app's Privacy Policy URL in App Store
/// Connect, not the Firebase host, which never served that path.
enum SubscriptionLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://moifort.github.io/shiori/")!
}

private struct BenefitRow: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
    }
}

/// One offer. The price and the period come from the `Product`, never from a
/// string in the app: Apple shows the storefront's own currency and amount.
/// The optional savings ratio is computed by the sheet from the loaded prices.
///
/// It has no preview of its own: StoreKit's `Product` cannot be built by hand, so
/// the button only renders through `PremiumSheet` once the store answered.
private struct OfferButton: View {
    let product: Product
    var savings: Decimal?
    let isPurchasing: Bool
    let buy: () async -> Void

    @State private var isBuying = false

    var body: some View {
        Button {
            Task {
                isBuying = true
                await buy()
                isBuying = false
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                        if let savingsBadge {
                            Text(savingsBadge)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.tint, in: Capsule())
                        }
                    }
                    if let introductoryOffer {
                        Text(introductoryOffer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isBuying {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(.headline)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    private var introductoryOffer: String? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial
        else { return nil }
        return offer.period.unit == .day
            ? String(localized: "\(offer.period.value) jours offerts")
            : String(localized: "\(offer.period.value) mois offerts")
    }

    /// The saving as a tinted capsule next to the plan's name, `-30 %`.
    private var savingsBadge: String? {
        guard let savings,
            let percent = Self.percentFormatter.string(from: savings as NSDecimalNumber)
        else { return nil }
        return "-\(percent)"
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

#Preview("Benefit rows") {
    VStack(alignment: .leading, spacing: 14) {
        BenefitRow(icon: "infinity", text: "Scans illimités")
        BenefitRow(icon: "sparkles", text: "Fiches enrichies par l'IA")
        BenefitRow(icon: "square.stack", text: "Catalogue complet des séries")
    }
    .padding()
}

#Preview("Allowance spent") {
    PremiumSheet(trigger: .scanAllowanceSpent)
        .environment(SubscriptionStore())
}

#Preview("Discover") {
    PremiumSheet(trigger: .discover)
        .environment(SubscriptionStore())
}
