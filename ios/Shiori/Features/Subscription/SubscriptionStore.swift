import Foundation
import StoreKit

/// The app's whole relationship with the App Store: what is for sale, what the
/// account owns, and the buying of it. Every purchase ends the same way — the
/// signed transaction goes to the server, which is what actually grants Premium.
/// The store never decides that on its own; `isPremium` is the server's answer.
@MainActor
@Observable
final class SubscriptionStore {
    /// The plan in force, as the server last told us. `nil` until it has.
    private(set) var isPremium: Bool?
    /// This month's allowance, as the server counts it. `nil` until read.
    private(set) var quota: QuotaState?
    /// The offers, App Store prices and all. Empty while loading, and when the
    /// products cannot be reached (no network, or no StoreKit configuration).
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    /// Set when a purchase or a restore failed in a way worth telling about — a
    /// cancelled purchase is not one.
    var errorMessage: String?

    /// The UUID a purchase must carry so the server can tie it to this account.
    /// It is derived server-side and fetched, never computed here: one algorithm,
    /// in one language.
    private var appAccountToken: UUID?
    /// `nonisolated` so `deinit` can cancel it: written once in `init`, read once
    /// when the store goes away, never concurrently.
    private nonisolated(unsafe) var updates: Task<Void, Never>?

    init() {
        // Renewals and revocations can land while the app is running — Apple
        // pushes them through this sequence, which must be listened to for the
        // whole lifetime of the app.
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.send(update)
                if case .verified(let transaction) = update { await transaction.finish() }
            }
        }
    }

    deinit { updates?.cancel() }

    /// Read the plan and the allowance from the server, load the offers, and
    /// report whatever the App Store already considers ours. Safe to call on
    /// every appearance.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        if let state = try? await SubscriptionAPI.load() {
            isPremium = state.isPremium
            appAccountToken = state.appAccountToken
        }
        quota = try? await SubscriptionAPI.quota()
        products = (try? await Product.products(for: SubscriptionProducts.all)) ?? []
        // Re-arm what Apple already sold us: a reinstall, a new device, or a
        // renewal that happened while the app was closed.
        await syncCurrentEntitlements()
    }

    /// Re-read only the allowance. What the scan screen calls after a scan, so
    /// the counter it shows is the server's, never one kept in the app.
    func refreshQuota() async {
        quota = try? await SubscriptionAPI.quota()
    }

    /// Buy one of the offers. Returns true when the account came out of it Premium.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard let appAccountToken else {
            errorMessage = String(localized: "Impossible de préparer l’achat. Réessayez dans un instant.")
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            switch result {
            case .success(let verification):
                let granted = await send(verification)
                if case .verified(let transaction) = verification { await transaction.finish() }
                // Apple has taken the money. If our own server would not grant the
                // Premium, saying nothing is the one thing we must not do: the
                // subscriber has paid and has nothing to show for it.
                if !granted {
                    errorMessage = String(localized: "L’achat a bien été enregistré par Apple, mais nous n’avons pas pu l’activer. Rouvrez l’app dans un instant : il sera repris automatiquement. Si rien ne change, touchez « Restaurer mes achats ».")
                }
                if granted {
                    // The end of the funnel, counted on what our own server
                    // granted rather than on what the App Store sheet said.
                    track(.purchaseCompleted(plan: product.id))
                    await refreshQuota()
                }
                return granted
            case .pending:
                // Ask-to-buy and other deferred approvals: nothing to do but wait
                // for Transaction.updates to fire.
                errorMessage = String(localized: "L’achat est en attente d’approbation.")
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    /// « Restaurer mes achats » — Apple requires the button to exist. Asking the
    /// App Store to resync is what recovers a subscription bought on another
    /// device; the entitlements it turns up are then sent to the server.
    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            let granted = await syncCurrentEntitlements()
            if granted {
                await refreshQuota()
            } else {
                errorMessage = String(localized: "Aucun abonnement à restaurer sur ce compte.")
            }
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Walk everything the App Store currently considers ours and hand it over.
    /// There is at most one subscription, but the sequence is the API. This is
    /// also the catch-up path: a purchase the server refused at the time is
    /// re-offered on every launch until it takes.
    @discardableResult
    private func syncCurrentEntitlements() async -> Bool {
        var granted = false
        for await entitlement in Transaction.currentEntitlements {
            if await send(entitlement) { granted = true }
        }
        return granted
    }

    /// The one path to Premium: the server verifies the signature and answers
    /// with the plan. An unverified result is not even sent — Apple already told
    /// us it does not check out. Returns whether the account came out of it
    /// Premium, so a caller can tell a refusal from a success instead of guessing
    /// from state that may not have moved.
    @discardableResult
    private func send(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified = result else { return false }
        guard let state = try? await SubscriptionAPI.sync(signedTransaction: result.jwsRepresentation)
        else { return false }
        isPremium = state.isPremium
        appAccountToken = state.appAccountToken ?? appAccountToken
        return state.isPremium
    }
}
