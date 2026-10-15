import SwiftUI

/// What an invitation shares, in one card: the row the other reader sees in
/// their list, under a short heading when the sheet does not already say it.
struct SharedSummary: View {
    let friend: Friend
    var heading: LocalizedStringKey? = "Ce que vous partagez"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let heading {
                Text(heading)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            FriendRow(friend: friend)
                .padding(.vertical, 12)
                // The list's own margin: the covers run out to the card's edge.
                .padding(.horizontal, 16)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    SharedSummary(friend: Friend.previews[0])
        .padding()
}
