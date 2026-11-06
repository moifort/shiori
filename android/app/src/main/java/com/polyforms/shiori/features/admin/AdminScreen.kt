package com.polyforms.shiori.features.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.graphql.AdminMetricsQuery
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.parseISO8601
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.reportError
import java.text.NumberFormat
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle as DateStyle
import java.util.Currency
import java.util.Locale

/** The month's figures for the admin: the bill, the readers, Premium, what Gemini searched. */
data class AdminMetrics(
    val month: LocalDate,
    val costs: Costs?,
    val sessions: List<DailySessions>?,
    val totalUsers: Int,
    val newUsers: Int,
    val premiumTotal: Int,
    val newPremium: Int,
    val revenueProceedsEur: Double?,
    val revenueGrossEur: Double?,
    val scans: Int,
    val cacheHits: Int,
    val searches: Int,
    val enrichmentSearches: Int,
    val catalogueSearches: Int,
    val discoverySearches: Int,
    val refreshedAt: java.time.Instant?,
) {
    data class DailyCost(val day: LocalDate, val geminiEur: Double, val infraEur: Double)
    data class DailySessions(val day: LocalDate, val sessions: Int)
    data class Costs(
        val geminiEur: Double,
        val infraEur: Double,
        val totalEur: Double,
        val projectedEur: Double?,
        val previousMonthEur: Double?,
        val changeVsPreviousMonth: Double?,
        val billedThrough: LocalDate?,
        val days: List<DailyCost>,
    )

    val daysInMonth: Int get() = month.lengthOfMonth()
}

object AdminApi {
    private fun day(value: String?) = value?.let { runCatching { LocalDate.parse(it) }.getOrNull() }

    suspend fun metrics(): AdminMetrics {
        val m = GraphQLClient.fetch(AdminMetricsQuery()).adminMetrics
        return AdminMetrics(
            month = LocalDate.now(ZoneOffset.UTC).withDayOfMonth(1),
            costs = m.costs?.let { c ->
                AdminMetrics.Costs(
                    c.geminiEur, c.infraEur, c.totalEur, c.projectedEur, c.previousMonthEur, c.changeVsPreviousMonth, day(c.billedThrough),
                    c.days.mapNotNull { d -> day(d.day)?.let { AdminMetrics.DailyCost(it, d.geminiEur, d.infraEur) } },
                )
            },
            sessions = m.sessions?.mapNotNull { s -> day(s.day)?.let { AdminMetrics.DailySessions(it, s.sessions) } },
            totalUsers = m.totalUsers,
            newUsers = m.newUsers,
            premiumTotal = m.premiumTotal,
            newPremium = m.newPremium,
            revenueProceedsEur = m.revenueProceedsEur,
            revenueGrossEur = m.revenueGrossEur,
            scans = m.scans,
            cacheHits = m.cacheHits,
            searches = m.searches,
            enrichmentSearches = m.enrichment.aiStepUsageFields.searches,
            catalogueSearches = m.catalogue.aiStepUsageFields.searches,
            discoverySearches = m.discovery.aiStepUsageFields.searches,
            refreshedAt = parseISO8601(m.refreshedAt),
        )
    }
}

private object AdminFormat {
    fun euro(value: Double): String = NumberFormat.getCurrencyInstance().apply {
        currency = Currency.getInstance("EUR")
        minimumFractionDigits = 2
        maximumFractionDigits = 2
    }.format(value)

    fun count(value: Int): String = NumberFormat.getIntegerInstance().format(value)
}

/** The admin's month, read from the server each time the page opens. */
@Composable
fun AdminScreen() {
    var metrics by remember { mutableStateOf<AdminMetrics?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var attempt by remember { mutableStateOf(0) }
    LaunchedEffect(attempt) {
        errorMessage = null
        try {
            metrics = AdminApi.metrics()
        } catch (error: Throwable) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        val shown = metrics
        val failed = errorMessage
        when {
            shown != null -> AdminPage(shown)
            failed != null -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
                FailureState(L("Métriques indisponibles"), failed) { attempt++ }
            }
            else -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        }
        ScreenBar(shown?.let { monthTitle(it.month) } ?: L("Admin"))
    }
}

private fun monthTitle(month: LocalDate) =
    "${month.month.getDisplayName(DateStyle.FULL, Locale.getDefault())} ${month.year}".replaceFirstChar { it.uppercase() }

@Composable
fun AdminPage(metrics: AdminMetrics) {
    val colors = Shiori.colors
    LazyColumn(Modifier.fillMaxSize().statusBarsPadding(), contentPadding = PaddingValues(top = 72.dp, bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        item(key = "top") {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                MonthCostCard(metrics.costs, metrics.month.minusMonths(1))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    KpiTile(L("Revenus Premium"), metrics.revenueProceedsEur?.let(AdminFormat::euro) ?: L("Indisponible"), metrics.revenueGrossEur?.let { L("%@ brut", AdminFormat.euro(it)) }, "banknote.fill", colors.green, Modifier.weight(1f))
                    KpiTile(L("Gemini / Infra"), metrics.costs?.let { AdminFormat.euro(it.geminiEur) } ?: L("Indisponible"), metrics.costs?.let { L("%@ d'infra", AdminFormat.euro(it.infraEur)) }, "sparkles", colors.purple, Modifier.weight(1f))
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    KpiTile(L("Utilisateurs"), AdminFormat.count(metrics.totalUsers), L("+%lld ce mois", metrics.newUsers), "person.2.fill", colors.blue, Modifier.weight(1f))
                    KpiTile(L("Premium"), AdminFormat.count(metrics.premiumTotal), L("+%lld ce mois", metrics.newPremium), "crown.fill", colors.orange, Modifier.weight(1f))
                }
            }
        }
        item(key = "costs") {
            FormSection(L("Coûts par jour")) {
                val costs = metrics.costs
                if (costs != null && costs.days.isNotEmpty()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Legend(L("Gemini"), colors.purple)
                            Legend(L("Infra"), colors.gray)
                        }
                        DailyBars(costs.days.map { Triple(it.day, listOf(it.geminiEur to colors.purple, it.infraEur to colors.gray), String.format(Locale.getDefault(), "%.2f", it.geminiEur + it.infraEur)) })
                    }
                } else {
                    Unavailable(if (costs == null) L("Facturation indisponible") else L("Aucun jour facturé"))
                }
            }
        }
        item(key = "sessions") {
            FormSection(L("Sessions par jour")) {
                val sessions = metrics.sessions
                if (!sessions.isNullOrEmpty()) {
                    Box(Modifier.padding(16.dp)) { DailyBars(sessions.map { Triple(it.day, listOf(it.sessions.toDouble() to colors.blue), it.sessions.toString()) }) }
                } else {
                    Unavailable(if (sessions == null) L("Sessions indisponibles") else L("Aucune session"))
                }
            }
        }
        item(key = "gemini") {
            FormSection(L("Gemini du mois")) {
                Labeled(L("Scans"), AdminFormat.count(metrics.scans))
                Labeled(L("Servis par le cache"), AdminFormat.count(metrics.cacheHits))
                Labeled(L("Recherches Google"), AdminFormat.count(metrics.searches), divider = false)
            }
        }
        item(key = "steps") {
            FormSection(L("Recherches Google par étape")) {
                Labeled(L("Enrichissement des scans"), AdminFormat.count(metrics.enrichmentSearches))
                Labeled(L("Catalogue des sagas"), AdminFormat.count(metrics.catalogueSearches))
                Labeled(L("Découvrir"), AdminFormat.count(metrics.discoverySearches), divider = false)
            }
        }
        item(key = "refresh") {
            FormSection(L("Actualisation")) {
                val refreshed = metrics.refreshedAt?.let { DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT).format(it.atZone(ZoneId.systemDefault())) } ?: L("Pas encore")
                Labeled(L("Facture, comptes et sessions"), refreshed, divider = false)
            }
        }
    }
}

@Composable
private fun MonthCostCard(costs: AdminMetrics.Costs?, previousMonth: LocalDate) {
    val colors = Shiori.colors
    Column(Modifier.fillMaxWidth().background(colors.secondaryGroupedBackground, RoundedCornerShape(12.dp)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Symbol("eurosign.circle.fill"), null, Modifier.size(14.dp), tint = colors.red)
            Text(L("Coût du mois"), style = Shiori.type.caption, color = colors.red)
        }
        Text(costs?.let { AdminFormat.euro(it.totalEur) } ?: L("Indisponible"), style = Shiori.type.largeTitle.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
        if (costs != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                costs.projectedEur?.let { Text(L("≈ %@ fin de mois", AdminFormat.euro(it)), style = Shiori.type.subheadline, color = colors.secondaryLabel) }
                costs.changeVsPreviousMonth?.let { change ->
                    val percent = (if (change > 0) "+" else "") + "${Math.round(change * 100)} %"
                    val month = previousMonth.month.getDisplayName(DateStyle.SHORT, Locale.getDefault())
                    Text(L("%@ vs %@", percent, month), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = if (change > 0) colors.red else colors.green)
                }
            }
            costs.billedThrough?.let {
                Text(L("Facturé jusqu'au %@", "${it.dayOfMonth} ${it.month.getDisplayName(DateStyle.SHORT, Locale.getDefault())}"), style = Shiori.type.caption, color = colors.tertiaryLabel)
            }
        }
    }
}

@Composable
private fun KpiTile(title: String, value: String, detail: String?, icon: String, tint: Color, modifier: Modifier = Modifier) {
    val colors = Shiori.colors
    Column(modifier.background(colors.secondaryGroupedBackground, RoundedCornerShape(12.dp)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Symbol(icon), null, Modifier.size(13.dp), tint = tint)
            Text(title, style = Shiori.type.caption, color = tint, maxLines = 1)
        }
        Text(value, style = Shiori.type.title3.copy(fontWeight = FontWeight.SemiBold), color = colors.label, maxLines = 1)
        detail?.let { Text(it, style = Shiori.type.caption, color = colors.secondaryLabel, maxLines = 1) }
    }
}

@Composable
private fun Legend(title: String, color: Color) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).background(color, CircleShape))
        Text(title, style = Shiori.type.caption, color = Shiori.colors.secondaryLabel)
    }
}

/** One bar per day, stacked, its total above and its day under it, scrolled to the latest. */
@Composable
private fun DailyBars(days: List<Triple<LocalDate, List<Pair<Double, Color>>, String>>) {
    val peak = maxOf(days.maxOfOrNull { d -> d.second.sumOf { it.first } } ?: 0.0, 1.0) * 1.25
    val scroll = rememberScrollState()
    LaunchedEffect(days.size) { scroll.scrollTo(scroll.maxValue) }
    Row(Modifier.fillMaxWidth().horizontalScroll(scroll), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Bottom) {
        days.forEach { (day, parts, label) ->
            Column(Modifier.width(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(label, style = TextStyle(fontSize = 9.sp), color = Shiori.colors.secondaryLabel, maxLines = 1, softWrap = false)
                Column(Modifier.height(120.dp).width(14.dp), verticalArrangement = Arrangement.Bottom) {
                    parts.reversed().forEach { (value, color) ->
                        if (value > 0) Box(Modifier.fillMaxWidth().height((120 * value / peak).dp).background(color, RoundedCornerShape(2.dp)))
                    }
                }
                Text("${day.dayOfMonth}", style = Shiori.type.caption2, color = Shiori.colors.tertiaryLabel, textAlign = TextAlign.Center)
            }
        }
    }
}

@Composable
private fun Unavailable(message: String) {
    Text(message, style = Shiori.type.body, color = Shiori.colors.secondaryLabel, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp))
}

@Composable
private fun Labeled(title: String, value: String, divider: Boolean = true) {
    FormRow(divider = divider) {
        Text(title, style = Shiori.type.body, color = Shiori.colors.label, modifier = Modifier.weight(1f))
        Text(value, style = Shiori.type.body, color = Shiori.colors.secondaryLabel)
    }
}
