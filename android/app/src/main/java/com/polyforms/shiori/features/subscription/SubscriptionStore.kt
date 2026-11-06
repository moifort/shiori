package com.polyforms.shiori.features.subscription

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.reportError
import com.polyforms.shiori.shared.track
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * The plan, the scan allowance and the Play offers. Every purchase Play Billing reports is
 * handed to the server, which is the only one that grants Premium: the app takes nothing from
 * Play on its own word.
 */
class SubscriptionStore(context: Context) {
    var isPremium by mutableStateOf<Boolean?>(null)
        private set
    var quota by mutableStateOf<QuotaState?>(null)
        private set
    var products by mutableStateOf<List<ProductDetails>>(emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var isPurchasing by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)

    private var appAccountToken: String? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingPurchase: CompletableDeferred<Boolean>? = null

    private val billing: BillingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener { result, purchases -> scope.launch { onPurchasesUpdated(result, purchases) } }
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    suspend fun refresh() {
        isLoading = true
        try {
            runCatching { SubscriptionApi.state() }.getOrNull()?.let { (entitlement, quota) -> apply(entitlement, quota) }
            loadOffers()
        } finally {
            isLoading = false
        }
    }

    suspend fun start(entitlement: EntitlementState, quota: QuotaState) {
        isLoading = true
        try {
            apply(entitlement, quota)
            loadOffers()
        } finally {
            isLoading = false
        }
    }

    private fun apply(entitlement: EntitlementState, quota: QuotaState) {
        isPremium = entitlement.isPremium
        appAccountToken = entitlement.appAccountToken
        this.quota = quota
    }

    suspend fun refreshQuota() {
        quota = runCatching { SubscriptionApi.quota() }.getOrNull()
    }

    private suspend fun connect(): Boolean {
        if (billing.isReady) return true
        val ready = CompletableDeferred<Boolean>()
        billing.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                ready.complete(result.responseCode == BillingClient.BillingResponseCode.OK)
            }

            override fun onBillingServiceDisconnected() {
                ready.complete(false)
            }
        })
        return ready.await()
    }

    private suspend fun loadOffers() {
        if (Showcase.isOn || !connect()) return
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                SubscriptionProducts.all.map {
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(it)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                },
            )
            .build()
        val result = billing.queryProductDetails(params)
        products = result.productDetailsList.orEmpty()
        syncCurrentPurchases()
    }

    /** Starts Play's purchase sheet; true once the server granted Premium. */
    suspend fun purchase(activity: Activity, product: ProductDetails): Boolean {
        val token = appAccountToken
        if (token == null) {
            errorMessage = L("Impossible de préparer l’achat. Réessayez dans un instant.")
            return false
        }
        val offer = product.subscriptionOfferDetails?.firstOrNull() ?: return false
        isPurchasing = true
        try {
            val deferred = CompletableDeferred<Boolean>()
            pendingPurchase = deferred
            val params = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(
                    listOf(
                        BillingFlowParams.ProductDetailsParams.newBuilder()
                            .setProductDetails(product)
                            .setOfferToken(offer.offerToken)
                            .build(),
                    ),
                )
                .setObfuscatedAccountId(token)
                .build()
            val launch = billing.launchBillingFlow(activity, params)
            if (launch.responseCode != BillingClient.BillingResponseCode.OK) {
                pendingPurchase = null
                return false
            }
            val granted = deferred.await()
            if (granted) {
                track(AnalyticsEvent.PurchaseCompleted(product.productId))
                refreshQuota()
            }
            return granted
        } finally {
            isPurchasing = false
        }
    }

    private suspend fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        val pending = pendingPurchase
        pendingPurchase = null
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                var granted = false
                for (purchase in purchases.orEmpty()) {
                    if (purchase.purchaseState == Purchase.PurchaseState.PENDING) {
                        errorMessage = L("L’achat est en attente d’approbation.")
                    } else if (send(purchase)) {
                        granted = true
                    }
                }
                if (!granted && purchases.orEmpty().any { it.purchaseState == Purchase.PurchaseState.PURCHASED }) {
                    errorMessage = L("L’achat a bien été enregistré, mais nous n’avons pas pu l’activer. Rouvrez l’app dans un instant : il sera repris automatiquement. Si rien ne change, touchez « Restaurer mes achats ».")
                }
                pending?.complete(granted)
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> pending?.complete(false)
            else -> {
                errorMessage = result.debugMessage.ifBlank { L("Achat impossible") }
                pending?.complete(false)
            }
        }
    }

    suspend fun restore() {
        isPurchasing = true
        try {
            if (!connect()) return
            if (syncCurrentPurchases()) refreshQuota() else errorMessage = L("Aucun abonnement à restaurer sur ce compte.")
        } catch (error: Exception) {
            errorMessage = reportError(error)
        } finally {
            isPurchasing = false
        }
    }

    /** Every subscription Play holds for this phone's account, handed to the server again. */
    private suspend fun syncCurrentPurchases(): Boolean {
        val owned = billing.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
        )
        var granted = false
        for (purchase in owned.purchasesList) if (send(purchase)) granted = true
        return granted
    }

    private suspend fun send(purchase: Purchase): Boolean {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return false
        val state = runCatching { SubscriptionApi.syncPlay(purchase.purchaseToken) }.getOrNull() ?: return false
        isPremium = state.isPremium
        appAccountToken = state.appAccountToken ?: appAccountToken
        // The server acknowledges; this is the fallback should its call have failed.
        if (!purchase.isAcknowledged) {
            runCatching {
                billing.acknowledgePurchase(
                    AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build(),
                ) {}
            }
        }
        return state.isPremium
    }
}

val LocalSubscriptionStore = staticCompositionLocalOf<SubscriptionStore> { error("No SubscriptionStore") }
