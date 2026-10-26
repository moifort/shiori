import SwiftUI

/// The search field under a large title, as the system draws it, that opens
/// the search when tapped: the search itself lives in its own sheet, which
/// takes the keyboard at once.
struct SearchFieldButton: View {
    var prompt: LocalizedStringKey = "Rechercher"
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                Text(prompt)
                Spacer(minLength: 0)
                Image(systemName: "mic.fill")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(prompt))
        .accessibilityAddTraits(.isSearchField)
    }
}

#Preview {
    SearchFieldButton {}
        .padding()
        .background(.black)
        .environment(\.colorScheme, .dark)
}
