import SwiftUI

/// A person a portrait rail draws: their face, else their initials, and their
/// name under it — an author, a narrator.
protocol PortraitPerson: Identifiable {
    var name: String { get }
    var initials: String { get }
    var portraitURL: URL? { get }
}

extension FollowedAuthor: PortraitPerson {}

/// People as round portraits in a rail, as the TV app lines up a cast: the
/// face and the name under it, nothing else. Three and a half fit a phone's
/// width, so the rail says it goes on.
struct PersonPortraitRail<Person: PortraitPerson>: View {
    let people: [Person]
    let onOpen: (Person) -> Void

    static var portraitSize: CGFloat { 93 }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(people) { person in
                    Button { onOpen(person) } label: {
                        VStack(spacing: 8) {
                            AuthorAvatar(initials: person.initials, portraitURL: person.portraitURL, size: Self.portraitSize)
                            Text(person.name)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: Self.portraitSize)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 20)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

#Preview {
    PersonPortraitRail(people: FollowedAuthor.previews) { _ in }
        .background(.black)
}
