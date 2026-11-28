import SwiftUI

/// What stands in for the app while the account holds no subscription. Shiori has no free
/// plan: a new reader meets it in the onboarding, after their first name and before their
/// libraries, as the free month to start, and
/// a reader whose trial or subscription ended meets it at launch, as the offer to come back.
/// The library is kept in both cases. Account deletion stays one tap away, as App Review
/// requires of an app that creates accounts.
struct SubscriptionWallPage: View {
    enum Kind: Equatable {
        /// The account may still start the free trial: the yearly plan opens on it.
        case trial
        /// The trial was used: the plans as they are, nothing free.
        case lapsed
    }

    let kind: Kind
    /// The yearly plan first, then the monthly one. Empty while loading or unreachable.
    let offers: [PremiumOffer]
    var savings: Decimal?
    var isLoading = false
    var isPurchasing = false
    var onBuy: (PremiumOffer) async -> Void
    var onRestore: () async -> Void
    var onAccount: () -> Void

    @State private var chosen: String?

    private var yearly: PremiumOffer? { offers.first { $0.id == SubscriptionProducts.yearly } }
    private var monthly: PremiumOffer? { offers.first { $0.id == SubscriptionProducts.monthly } }
    private var selected: PremiumOffer? { offers.first { $0.id == chosen } ?? offers.first }

    var body: some View {
        ScrollView {
            VStack(alignment: kind == .trial ? .leading : .center, spacing: 24) {
                header
                promise
                offersView
                if kind == .lapsed {
                    VStack(spacing: 14) {
                        action
                        legal
                    }
                }
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            // The free month sits in the onboarding as its other pages do: the
            // terms, then the button, held at the foot of the screen.
            if kind == .trial {
                VStack(spacing: 14) {
                    legal
                    action
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        switch kind {
        case .trial:
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(Color.orange, in: .rect(cornerRadius: 22))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Votre mois offert")
                        .font(.title.bold())
                    Text("Shiori s’utilise avec un abonnement. Le premier mois est offert, et rien n’est prélevé si vous résiliez avant sa fin.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        case .lapsed:
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                Text("Votre essai est terminé")
                    .font(.title2.bold())
                Text("Vos livres, vos séries et vos notes sont gardés. Abonnez-vous pour retrouver votre bibliothèque.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var promise: some View {
        switch kind {
        case .trial:
            PremiumPromise()
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        case .lapsed:
            PremiumPromise()
        }
    }

    @ViewBuilder
    private var offersView: some View {
        if offers.isEmpty {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Text("Les offres ne sont pas disponibles pour le moment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        } else {
            switch kind {
            case .trial:
                if let yearly {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(yearly.trial ?? String(localized: "1 mois offert"))
                                .font(.headline)
                            Text("puis \(yearly.displayPrice) par an")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Résiliable à tout moment")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 16))
                }
            case .lapsed:
                VStack(spacing: 10) {
                    ForEach(offers) { offer in
                        planRow(offer)
                    }
                }
            }
        }
    }

    private func planRow(_ offer: PremiumOffer) -> some View {
        let isSelected = offer.id == selected?.id
        return Button {
            chosen = offer.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(offer.name).font(.headline)
                        if offer.id == SubscriptionProducts.yearly, let badge = savingsBadge {
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.16), in: Capsule())
                        }
                    }
                    if offer.id == SubscriptionProducts.yearly, let perMonth = Self.perMonth(offer) {
                        Text("soit \(perMonth) par mois")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(offer.displayPrice).font(.headline)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 16))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(.white, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var action: some View {
        switch kind {
        case .trial:
            VStack(spacing: 12) {
                buyButton("Commencer le mois offert", offer: yearly, identifier: "wall-start-trial")
                if let monthly {
                    AsyncButton("Ou \(monthly.displayPrice) par mois, sans essai") { await onBuy(monthly) }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .disabled(isPurchasing)
                        .accessibilityIdentifier("wall-buy-monthly")
                }
            }
        case .lapsed:
            buyButton("S’abonner", offer: selected, identifier: "wall-subscribe")
        }
    }

    private func buyButton(_ title: LocalizedStringKey, offer: PremiumOffer?, identifier: String) -> some View {
        Button {
            guard let offer else { return }
            Task { await onBuy(offer) }
        } label: {
            ZStack {
                Text(title).opacity(isPurchasing ? 0 : 1)
                if isPurchasing { ProgressView() }
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isPurchasing || offer == nil)
        .buttonStyle(.actionWide)
        .controlSize(.large)
        .tint(.white)
        .foregroundStyle(.black)
        .accessibilityIdentifier(identifier)
    }

    private var legal: some View {
        VStack(spacing: 8) {
            Text("Renouvellement automatique, résiliable à tout moment dans les réglages du compte App Store.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                Link("Conditions d’utilisation", destination: SubscriptionLinks.terms)
                Text(verbatim: "·").foregroundStyle(.secondary)
                Link("Confidentialité", destination: SubscriptionLinks.privacy)
                Text(verbatim: "·").foregroundStyle(.secondary)
                AsyncButton("Restaurer mes achats") { await onRestore() }
                    .disabled(isPurchasing)
            }
            .font(.caption)
            .foregroundStyle(.white)
            Button("Supprimer mon compte", action: onAccount)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("wall-account")
        }
        .frame(maxWidth: .infinity)
    }

    /// The saving as `-42 %`, computed by the screen from the store's own prices.
    private var savingsBadge: String? {
        guard let savings,
            let percent = Self.percent.string(from: savings as NSDecimalNumber)
        else { return nil }
        return "-\(percent)"
    }

    /// The yearly price spread over twelve months, in the storefront's currency.
    static func perMonth(_ offer: PremiumOffer) -> String? {
        guard let product = offer.product else { return offer.perMonthForCapture }
        return (product.price / 12).formatted(product.priceFormatStyle)
    }

    private static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

/// The two plans as France sells them, for the previews and the captures.
extension PremiumOffer {
    static let previewOffers = [
        PremiumOffer(
            id: SubscriptionProducts.yearly, name: "Premium annuel", displayPrice: "34,99 €",
            price: 34.99, trial: "1 mois offert", perMonthForCapture: "2,92 €"
        ),
        PremiumOffer(
            id: SubscriptionProducts.monthly, name: "Premium mensuel", displayPrice: "4,99 €",
            price: 4.99
        ),
    ]
}

#Preview("Le mois offert") {
    SubscriptionWallPage(
        kind: .trial, offers: PremiumOffer.previewOffers, savings: 0.42,
        onBuy: { _ in }, onRestore: {}, onAccount: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Essai terminé") {
    SubscriptionWallPage(
        kind: .lapsed, offers: PremiumOffer.previewOffers, savings: 0.42,
        onBuy: { _ in }, onRestore: {}, onAccount: {}
    )
    .preferredColorScheme(.dark)
}
