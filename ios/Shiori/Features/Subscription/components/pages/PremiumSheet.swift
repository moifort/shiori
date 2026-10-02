import StoreKit
import SwiftUI

/// Why the sheet came up. Only the headline changes: the offer is the same
/// whether it was reached from the settings or by running out of scans.
enum PremiumTrigger {
    case scanAllowanceSpent
    case discover
    case shelfImport

    var title: String {
        switch self {
        case .scanAllowanceSpent: return String(localized: "Scans épuisés")
        case .discover: return String(localized: "Shiori Premium")
        case .shelfImport: return String(localized: "Plusieurs livres d'un coup")
        }
    }

    /// What GA4 reads to tell the paywall that sells from the one that consoles.
    var analyticsName: String {
        switch self {
        case .scanAllowanceSpent: return "scan_allowance_spent"
        case .discover: return "discover"
        case .shelfImport: return "shelf_import"
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
        case .shelfImport:
            return String(localized: "Photographiez une étagère entière : chaque livre est reconnu, vous cochez ceux à ajouter. Réservé à Shiori Premium.")
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

    /// The plans in the order they are declared in, not whatever the App Store
    /// returns: yearly first, the offer put forward.
    private var plans: [PremiumOffer] {
        #if DEBUG
        if Showcase.isOn { return Showcase.offers }
        #endif
        return SubscriptionProducts.all.compactMap { id in
            store.products.first { $0.id == id }.map(PremiumOffer.init)
        }
    }

    @ViewBuilder
    private var offers: some View {
        if store.isLoading && plans.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if plans.isEmpty {
            Text("Les offres ne sont pas disponibles pour le moment.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 12) {
                ForEach(plans) { plan in
                    OfferButton(
                        offer: plan,
                        savings: plan.id == SubscriptionProducts.yearly ? yearlySavings : nil,
                        isPurchasing: store.isPurchasing
                    ) {
                        guard let product = plan.product else { return }
                        if await store.purchase(product) { dismiss() }
                    }
                }
            }
        }
    }

    /// What the yearly plan saves against twelve months of the monthly plan,
    /// computed from the store's own prices so the label can never contradict
    /// them. Nil while either product is missing, or if the yearly plan does
    /// not actually save anything.
    private var yearlySavings: Decimal? {
        guard
            let yearly = plans.first(where: { $0.id == SubscriptionProducts.yearly }),
            let monthly = plans.first(where: { $0.id == SubscriptionProducts.monthly }),
            monthly.price > 0
        else { return nil }
        let twelveMonths = monthly.price * 12
        let savings = (twelveMonths - yearly.price) / twelveMonths
        return savings > 0 ? savings : nil
    }

    private var legal: some View {
        VStack(spacing: 12) {
            AsyncButton("Restaurer mes achats") { await store.restore() }
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

/// One plan as the sheet draws it. The price and the period come from the
/// `Product`, never from a string in the app: Apple shows the storefront's own
/// currency and amount. Held apart from the `Product` because StoreKit's cannot
/// be built by hand, and the App Store captures draw the sheet without a store.
struct PremiumOffer: Identifiable {
    let id: String
    let name: String
    let displayPrice: String
    let price: Decimal
    /// "1 semaine offerte", for a plan that opens on a free trial.
    var trial: String?
    /// What a tap buys. Nil on a plan drawn for a capture.
    var product: Product?

    init(id: String, name: String, displayPrice: String, price: Decimal, trial: String? = nil) {
        self.id = id
        self.name = name
        self.displayPrice = displayPrice
        self.price = price
        self.trial = trial
    }

    init(product: Product) {
        self.init(
            id: product.id,
            name: product.displayName,
            displayPrice: product.displayPrice,
            price: product.price,
            trial: product.subscription?.introductoryOffer
                .flatMap { $0.paymentMode == .freeTrial ? Self.trialLabel($0.period) : nil }
        )
        self.product = product
    }

    /// The free period, in the unit the App Store declares it in: reading every
    /// period as days or months called a week a month.
    static func trialLabel(_ period: Product.SubscriptionPeriod) -> String {
        let count = period.value
        return switch period.unit {
        case .day: count == 1 ? String(localized: "1 jour offert") : String(localized: "\(count) jours offerts")
        case .week: count == 1
            ? String(localized: "1 semaine offerte")
            : String(localized: "\(count) semaines offertes")
        case .month: count == 1 ? String(localized: "1 mois offert") : String(localized: "\(count) mois offerts")
        case .year: count == 1 ? String(localized: "1 an offert") : String(localized: "\(count) ans offerts")
        @unknown default: String(localized: "Essai gratuit")
        }
    }
}

/// One offer. The optional savings ratio is computed by the sheet from the
/// loaded prices.
private struct OfferButton: View {
    let offer: PremiumOffer
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
                        Text(offer.name)
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
                    if let trial = offer.trial {
                        Text(trial)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isBuying {
                    ProgressView()
                } else {
                    Text(offer.displayPrice)
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
