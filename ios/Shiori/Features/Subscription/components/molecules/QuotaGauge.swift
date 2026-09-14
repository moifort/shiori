import SwiftUI

/// The scan allowance, as a counter and a bar: this month's consumption, plus the
/// scans granted at onboarding when any are left. Primitive-first: it is handed
/// plain numbers, never the API's state, so it stays previewable and the caller
/// decides who deserves to see it.
///
/// Shown to free accounts only. A subscriber is metered too — an anti-abuse
/// ceiling — but showing it would contradict the unlimited scanning the very same
/// sheet is selling, and no real subscriber ever approaches it.
struct QuotaGauge: View {
    let used: Int
    let limit: Int
    /// Granted scans still in hand. They are spent only once the month is, so
    /// they are shown apart rather than folded into the bar, which counts a
    /// window that resets.
    var welcomeRemaining: Int = 0
    let renewsOn: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scans ce mois-ci")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(used) / \(limit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(isExhausted ? .red : .secondary)
            }

            // Tinted red only once nothing is left anywhere: while granted scans
            // remain, the month running out changes nothing for the user.
            ProgressView(value: Double(min(used, limit)), total: Double(max(limit, 1)))
                .tint(isExhausted ? .red : nil)

            if welcomeRemaining > 0 {
                Label(
                    "\(welcomeRemaining) scans offerts en réserve",
                    systemImage: "gift"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let renewsOn {
                Text("Renouvellement le \(renewsOn.formatted(date: .long, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        // Read as one thing: spelled out, "3 / 5" and the bar's percentage are
        // the same fact twice, and neither says what it counts.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(totalRemaining) scans restants"))
    }

    /// Nothing left anywhere — the month spent and no granted scan behind it,
    /// which is exactly when the server starts refusing.
    private var isExhausted: Bool { totalRemaining == 0 }

    /// Never negative, the way the server counts it.
    private var monthlyRemaining: Int { max(0, limit - used) }

    private var totalRemaining: Int { monthlyRemaining + welcomeRemaining }
}

#Preview("Intact") {
    QuotaGauge(used: 0, limit: 5, renewsOn: Date().addingTimeInterval(9 * 86_400))
        .padding()
}

#Preview("Partly used") {
    QuotaGauge(used: 3, limit: 5, renewsOn: Date().addingTimeInterval(9 * 86_400))
        .padding()
}

#Preview("Exhausted") {
    QuotaGauge(used: 5, limit: 5, renewsOn: Date().addingTimeInterval(9 * 86_400))
        .padding()
}

#Preview("Month spent, granted scans left") {
    QuotaGauge(
        used: 5,
        limit: 5,
        welcomeRemaining: 14,
        renewsOn: Date().addingTimeInterval(9 * 86_400)
    )
    .padding()
}
