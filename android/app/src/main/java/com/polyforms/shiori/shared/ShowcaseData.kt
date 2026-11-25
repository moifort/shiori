package com.polyforms.shiori.shared

import com.polyforms.shiori.features.subscription.EntitlementState
import com.polyforms.shiori.features.subscription.QuotaState
import com.polyforms.shiori.features.subscription.SubscriptionProducts
import com.polyforms.shiori.features.subscription.components.pages.PremiumOffer
import java.time.Instant
import java.time.temporal.ChronoUnit

/** The App Store fixtures (`Showcase.swift`), as the Android captures draw them. */
object ShowcaseData {
    /** What a saga's screen holds in the showcase: the reader's volumes and the catalogue. */
    data class SeriesScreen(val owned: List<Book>, val series: BookSeries?)

    val books: List<Book> get() = ShowcaseLibrary.books

    fun book(id: String): Book? = books.firstOrNull { it.id == id }

    fun seriesScreen(id: String): SeriesScreen =
        SeriesScreen(books.filter { it.series?.id == id }, ShowcaseLibrary.series.firstOrNull { it.id == id })

    const val firstName = "Camille"

    val entitlement = EntitlementState(isPremium = false, appAccountToken = null, productId = null, expiresOn = null)

    val quota = QuotaState(
        isPremium = false,
        used = 0,
        limit = 0,
        remaining = 0,
        welcomeRemaining = 38,
        totalRemaining = 38,
        renewsOn = Instant.now().plus(18, ChronoUnit.DAYS),
    )

    val offers = listOf(
        PremiumOffer(SubscriptionProducts.YEARLY, L("Premium annuel"), "34,99 €", 34_990_000, L("1 mois offert"), perMonth = "2,92 €"),
        PremiumOffer(SubscriptionProducts.MONTHLY, L("Premium mensuel"), "4,99 €", 4_990_000),
    )
}
