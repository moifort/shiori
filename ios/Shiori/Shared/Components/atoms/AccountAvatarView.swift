import SwiftUI

/// The reader's face, in a circle: a hero's portrait, their photo, or their
/// initials on a slate disc as the TV app draws an account with no picture —
/// and while the photo loads, so the circle never flashes empty.
struct AccountAvatarView: View {
    let avatar: AccountAvatar
    let firstName: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            switch avatar {
            case .initials:
                monogram
            case let .hero(hero):
                Image(hero.imageName).resizable().scaledToFill()
            case let .photo(url):
                CoverImage(url: url) { monogram } fallback: { monogram }
            case let .pickedPhoto(data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    monogram
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private var monogram: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.62, green: 0.65, blue: 0.7), Color(red: 0.4, green: 0.43, blue: 0.48)],
                startPoint: .top,
                endPoint: .bottom
            )
            let letters = initials(of: firstName)
            if letters.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.white)
                    .offset(y: size * 0.08)
            } else {
                Text(verbatim: letters)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        AccountAvatarView(avatar: .initials, firstName: "Thibaut")
        AccountAvatarView(avatar: .initials, firstName: nil)
        AccountAvatarView(avatar: .hero(.holmes), firstName: "Thibaut", size: 84)
        AccountAvatarView(avatar: .hero(.alice), firstName: "Thibaut", size: 120)
    }
    .padding()
}
