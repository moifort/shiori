import SwiftUI

/// The admin screen, pure and previewable: the month's bill and where it is
/// heading, the key figures as tiles, the bill and the sessions day by day, then
/// the Gemini calls the app counted — where the bill comes from.
struct AdminPage: View {
    let metrics: AdminMetrics?
    var isLoading = false
    var errorMessage: String?
    var onRetry: () async -> Void = {}

    var body: some View {
        Group {
            if let metrics {
                content(metrics)
            } else if let errorMessage {
                EmptyStateView.failure("Métriques indisponibles", message: errorMessage, retry: onRetry)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(metrics.map { monthTitle($0.month) } ?? String(localized: "Admin"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ metrics: AdminMetrics) -> some View {
        List {
            Section {
                VStack(spacing: 12) {
                    AdminMonthCostCard(costs: metrics.costs, previousMonth: previousMonth(metrics.month))
                    keyTiles(metrics)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Coûts par jour") {
                if let costs = metrics.costs, !costs.days.isEmpty {
                    AdminDailyCostChart(
                        days: costs.days, monthStart: metrics.month, monthEnd: metrics.monthEnd
                    )
                    .padding(.vertical, 8)
                } else {
                    unavailable(metrics.costs == nil ? "Facturation indisponible" : "Aucun jour facturé")
                }
            }

            Section("Sessions par jour") {
                if let sessions = metrics.sessions, !sessions.isEmpty {
                    AdminDailySessionsChart(
                        days: sessions, monthStart: metrics.month, monthEnd: metrics.monthEnd
                    )
                    .padding(.vertical, 8)
                } else {
                    unavailable(metrics.sessions == nil ? "Sessions indisponibles" : "Aucune session")
                }
            }

            Section("Gemini du mois") {
                LabeledContent("Scans", value: AdminFormat.count(metrics.scans))
                LabeledContent("Servis par le cache", value: AdminFormat.count(metrics.cacheHits))
                LabeledContent("Recherches Google", value: AdminFormat.count(metrics.searches))
            }

            Section("Recherches Google par étape") {
                LabeledContent("Enrichissement des scans", value: AdminFormat.count(metrics.enrichment.searches))
                LabeledContent("Catalogue des sagas", value: AdminFormat.count(metrics.catalogue.searches))
                LabeledContent("Découvrir", value: AdminFormat.count(metrics.discovery.searches))
            }

            Section("Actualisation") {
                LabeledContent("Facture, comptes et sessions", value: refreshed(metrics.refreshedAt))
            }
        }
    }

    private func keyTiles(_ metrics: AdminMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            AdminKpiTile(
                title: "Revenus Premium",
                value: euroOrUnavailable(metrics.revenueProceedsEur),
                detail: metrics.revenueGrossEur.map { String(localized: "\(AdminFormat.euro($0)) brut") },
                icon: "banknote.fill",
                tint: .green
            )
            AdminKpiTile(
                title: "Gemini / Infra",
                value: metrics.costs.map { AdminFormat.euro($0.geminiEur) } ?? String(localized: "Indisponible"),
                detail: metrics.costs.map { String(localized: "\(AdminFormat.euro($0.infraEur)) d'infra") },
                icon: "sparkles",
                tint: .purple
            )
            AdminKpiTile(
                title: "Utilisateurs",
                value: AdminFormat.count(metrics.totalUsers),
                detail: String(localized: "+\(metrics.newUsers) ce mois"),
                icon: "person.2.fill",
                tint: .blue
            )
            AdminKpiTile(
                title: "Premium",
                value: AdminFormat.count(metrics.premiumTotal),
                detail: String(localized: "+\(metrics.newPremium) ce mois"),
                icon: "crown.fill",
                tint: .orange
            )
        }
    }

    private func unavailable(_ message: LocalizedStringKey) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    private func euroOrUnavailable(_ value: Double?) -> String {
        value.map(AdminFormat.euro) ?? String(localized: "Indisponible")
    }

    private func refreshed(_ refreshedAt: Date?) -> String {
        refreshedAt?.formatted(date: .abbreviated, time: .shortened)
            ?? String(localized: "Pas encore")
    }

    private func monthTitle(_ month: Date) -> String {
        var style = Date.FormatStyle(timeZone: TimeZone(identifier: "UTC")!).month(.wide).year()
        style.calendar = AdminMetrics.utc
        return month.formatted(style).capitalized
    }

    private func previousMonth(_ month: Date) -> Date {
        AdminMetrics.utc.date(byAdding: .month, value: -1, to: month) ?? month
    }
}

#Preview("Mid-month") {
    NavigationStack {
        AdminPage(metrics: .preview)
    }
}

#Preview("First billed month") {
    NavigationStack {
        AdminPage(metrics: .previewFirstMonth)
    }
}

#Preview("Before the first refresh") {
    NavigationStack {
        AdminPage(metrics: .previewBeforeRefresh)
    }
}

#Preview("Load failed") {
    NavigationStack {
        AdminPage(metrics: nil, errorMessage: "La connexion a échoué.")
    }
}
