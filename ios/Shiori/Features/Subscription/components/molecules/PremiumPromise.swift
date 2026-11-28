import SwiftUI

/// What Premium gives, in the same four lines wherever it is offered: the wall that stands
/// in for the app without a subscription, and the Premium sheet. Shiori has no free plan, so
/// these are what the app is: kept in step with the board's « Premium — plus de compte
/// gratuit » artboards.
struct PremiumPromise: View {
    var body: some View {
        VStack(spacing: 0) {
            row(
                icon: "arrow.triangle.2.circlepath",
                title: "Kindle et Audible à jour",
                detail: "Vos achats et vos lectures arrivent chaque nuit, sans rien faire."
            )
            Divider().padding(.leading, 44)
            row(
                icon: "bell",
                title: "Alertes de sortie",
                detail: "Le prochain tome de vos séries, dès que sa date est connue."
            )
            Divider().padding(.leading, 44)
            row(
                icon: "sparkles",
                title: "Des découvertes sur mesure",
                detail: "Chaque mois, des livres choisis pour vous d'après vos lectures et vos envies."
            )
            Divider().padding(.leading, 44)
            row(
                icon: "camera.viewfinder",
                title: "Une couverture ou une étagère en photo",
                detail: "Chaque livre reconnu, avec son résumé et sa série. 30 scans par mois, et 200 au premier paiement."
            )
        }
    }

    private func row(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    PremiumPromise()
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        .padding()
        .preferredColorScheme(.dark)
}
