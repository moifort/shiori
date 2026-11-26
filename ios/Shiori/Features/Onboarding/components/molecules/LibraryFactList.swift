import SwiftUI

/// A rounded box of lines, each a symbol in a small circle, a title and a
/// detail: the same box as the Goodreads export steps, a symbol in place of
/// the number.
struct LibraryFactList: View {
    let facts: [OnboardingLibrary.Fact]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { offset, fact in
                if offset > 0 { Divider().padding(.leading, 40) }
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: fact.symbol)
                        .font(.footnote.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemFill), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.title)
                        Text(fact.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 26))
    }
}

#Preview {
    LibraryFactList(facts: OnboardingLibrary.audible.brings)
        .padding()
        .environment(\.colorScheme, .dark)
}
