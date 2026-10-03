import SwiftUI

/// The admin screen, pure and previewable: the four key figures as tiles, then
/// the month's revenue, costs, readers and what each Gemini step consumed.
/// Grounded searches get their own lines: billed one by one, they are most of
/// the Gemini bill.
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
        .navigationTitle("Admin")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ metrics: AdminMetrics) -> some View {
        List {
            Section {
                keyTiles(metrics)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("CA du mois") {
                LabeledContent("Net encaissé", value: euroOrUnavailable(metrics.revenueProceedsEur))
                LabeledContent("Brut", value: euroOrUnavailable(metrics.revenueGrossEur))
            }

            Section("Coûts du mois") {
                LabeledContent("Total", value: euro(metrics.totalCostEur))
                LabeledContent("Recherches Google", value: euro(metrics.searchCostEur))
                LabeledContent("Tokens Gemini", value: euro(metrics.tokenCostEur))
                LabeledContent("Infra (GCP)", value: euroOrUnavailable(metrics.infraEur))
            }

            Section("Lecteurs") {
                LabeledContent("Comptes", value: "\(metrics.totalUsers)")
                LabeledContent("Premium mensuel", value: "\(metrics.premiumMonthly)")
                LabeledContent("Premium annuel", value: "\(metrics.premiumYearly)")
            }

            Section("Gemini du mois") {
                LabeledContent("Scans", value: count(metrics.scans))
                LabeledContent("Servis par le cache", value: count(metrics.cacheHits))
                LabeledContent("Recherches Google", value: count(metrics.searches))
            }

            stepSection("Vision", usage: metrics.vision)
            stepSection("Enrichissement", usage: metrics.enrichment)
            stepSection("Catalogue", usage: metrics.catalogue)
            stepSection("Découvrir", usage: metrics.discovery)

            Section {
                LabeledContent("Comptes, abonnés et CA", value: refreshed(metrics.refreshedAt))
            } header: {
                Text("Actualisation")
            }
        }
    }

    private func keyTiles(_ metrics: AdminMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile(title: "Gemini", value: euro(metrics.aiCostEur), icon: "sparkles", tint: .purple)
            tile(title: "Infra", value: euroOrUnavailable(metrics.infraEur), icon: "server.rack", tint: .gray)
            tile(title: "Comptes", value: "\(metrics.totalUsers)", icon: "person.2.fill", tint: .blue)
            tile(title: "Premium", value: "\(metrics.premiumTotal)", icon: "crown.fill", tint: .orange)
        }
    }

    private func tile(title: LocalizedStringKey, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func stepSection(_ title: LocalizedStringKey, usage: AdminMetrics.StepUsage) -> some View {
        Section(title) {
            LabeledContent("Tokens en entrée", value: count(usage.promptTokens))
            LabeledContent("Tokens en sortie", value: count(usage.outputTokens))
            LabeledContent("Tokens de réflexion", value: count(usage.thinkingTokens))
            LabeledContent("Recherches Google", value: count(usage.searches))
        }
    }

    private func euro(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").precision(.fractionLength(2)))
    }

    private func euroOrUnavailable(_ value: Double?) -> String {
        value.map(euro) ?? String(localized: "Indisponible")
    }

    private func count(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private func refreshed(_ refreshedAt: Date?) -> String {
        refreshedAt?.formatted(date: .abbreviated, time: .shortened)
            ?? String(localized: "Pas encore")
    }
}

#Preview("Loaded") {
    NavigationStack {
        AdminPage(metrics: .preview)
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
