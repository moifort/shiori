import SwiftUI

/// Everything a shelf of people — the authors, the narrators — can ask for.
enum PersonShelfAction<Person: ShelvedPerson> {
    case openPerson(Person)
    case openBook(Book)
    case order(AuthorListOrder)
    case menu(Book, BookQuickAction)
    case reached(String)
    case loadMore
    case refresh
}

/// The authors, or the narrators, as the TV app lists a filmography: a row per
/// person — the portrait and the name, opening their page — then their books
/// as posters, the line in each cover as everywhere: the stars, "Ajouté", the
/// bookmark. Ordered by the pills: the hearted alone, the most recent, or A
/// to Z — which the Music app's artists list draws instead: a letter, a row
/// per person, the index on the edge. Outside "Préférés" a heart follows the
/// name of whoever the reader hearted.
struct PersonShelfPage<Person: ShelvedPerson>: View {
    let title: LocalizedStringKey
    let failureTitle: LocalizedStringKey
    /// What "Préférés" says while the reader has hearted nobody.
    let noFavoritesTitle: LocalizedStringKey
    let noFavoritesMessage: LocalizedStringKey
    /// What UI tests find each row by.
    let rowIdentifier: String
    let people: [Person]
    let order: AuthorListOrder
    let isLoading: Bool
    let errorMessage: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    let onAction: (PersonShelfAction<Person>) -> Void

    private static var orders: [AuthorListOrder] { [.loved, .recent, .name] }

    var body: some View {
        Group {
            if order == .name {
                alphabetical
            } else {
                shelves
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .refreshable { onAction(.refresh) }
        .overlay {
            if people.isEmpty {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    EmptyState.failure(failureTitle, message: errorMessage) { onAction(.refresh) }
                } else if order == .loved {
                    EmptyState(systemImage: "heart", title: noFavoritesTitle, message: noFavoritesMessage)
                }
            }
        }
    }

    private var pills: some View {
        FilterPills(
            pills: Self.orders.map { FilterPills.Pill(id: $0.rawValue, label: $0.pillLabel) },
            selected: order.rawValue,
            allLabel: nil
        ) { id in
            if let order = id.flatMap(AuthorListOrder.init(rawValue:)) { onAction(.order(order)) }
        }
    }

    @ViewBuilder private var loadMore: some View {
        if hasMore {
            LoadMoreRow(
                failed: loadMoreFailed,
                loadingLabel: "Chargement de la suite",
                onLoadMore: { onAction(.loadMore) }
            )
        }
    }

    /// "Préférés" and "Récents": a row per person, their posters under it.
    private var shelves: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                pills
                ForEach(people) { person in
                    row(person)
                        .onAppear { onAction(.reached(person.id)) }
                }
                loadMore
            }
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
    }

    /// "A–Z", as the Music app lists its artists: the people under their
    /// letter, one line each, the letters on the trailing edge to jump by.
    private var alphabetical: some View {
        List {
            pills
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            ForEach(letterSections, id: \.letter) { section in
                // The letter is the section's first row rather than its
                // header: a header would stay pinned under the clear bar.
                Section {
                    Text(section.letter)
                        .font(.title3.weight(.bold))
                        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(section.people) { person in
                        alphabeticalRow(person)
                            .onAppear { onAction(.reached(person.id)) }
                    }
                }
                .sectionIndexLabel(section.letter)
            }
            loadMore
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .listSectionIndexVisibility(.visible)
        .scrollContentBackground(.hidden)
    }

    /// The people under their letter, each letter once and A to Z with "#"
    /// last, the server's order kept inside a letter: a row filed out of
    /// order joins its letter rather than opening it a second time.
    private var letterSections: [(letter: String, people: [Person])] {
        Self.letterSections(of: people)
    }

    static func letterSections(of people: [Person]) -> [(letter: String, people: [Person])] {
        Dictionary(grouping: people, by: \.indexLetter)
            .map { (letter: $0.key, people: $0.value) }
            .sorted { left, right in
                if (left.letter == "#") != (right.letter == "#") { return right.letter == "#" }
                return left.letter.localizedStandardCompare(right.letter) == .orderedAscending
            }
    }

    private func alphabeticalRow(_ person: Person) -> some View {
        Button { onAction(.openPerson(person)) } label: {
            HStack(spacing: 14) {
                AuthorAvatar(initials: person.initials, portraitURL: person.portraitURL, size: 48)
                HStack(spacing: 6) {
                    Text(Self.name(of: person))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if person.favorite { favoriteHeart }
                }
                // The hairline starts under the name, as in Music.
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 28))
        .listRowBackground(Color.clear)
        .accessibilityIdentifier(rowIdentifier)
    }

    /// The name with its surname in bold, as Contacts sets it, so the first
    /// name and the surname tell apart: "Ursula K. **Le Guin**".
    static func name(of person: Person) -> AttributedString {
        guard let surname = person.surname, !surname.isEmpty, person.name.hasSuffix(surname) else {
            return AttributedString(person.name)
        }
        var bold = AttributedString(surname)
        bold.inlinePresentationIntent = .stronglyEmphasized
        return AttributedString(person.name.dropLast(surname.count)) + bold
    }

    /// The reader hearted them: in the text's own colour, as every mark is
    /// off a cover.
    private var favoriteHeart: some View {
        Image(systemName: "heart.fill")
            .font(.footnote)
            .foregroundStyle(.primary)
            .accessibilityLabel("Préféré")
    }

    private func row(_ person: Person) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { onAction(.openPerson(person)) } label: {
                HStack(spacing: 10) {
                    AuthorAvatar(initials: person.initials, portraitURL: person.portraitURL, size: 40)
                    Text(person.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if person.favorite, order != .loved { favoriteHeart }
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .accessibilityIdentifier(rowIdentifier)
            PosterRow(
                items: person.books.map { .init(book: $0, label: PosterLabel.of($0, in: .recent)) },
                onOpen: { onAction(.openBook($0)) },
                onMenu: { onAction(.menu($0, $1)) }
            )
            .contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }
}

extension AuthorListOrder {
    /// The pill that orders the authors this way.
    var pillLabel: String {
        switch self {
        case .loved: String(localized: "Préférés")
        case .recent: String(localized: "Récents")
        case .name: String(localized: "A–Z")
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PersonShelfPage(
            title: "Auteurs",
            failureTitle: "Auteurs indisponibles",
            noFavoritesTitle: "Aucun auteur préféré",
            noFavoritesMessage: "Touchez le cœur sur la page d’un auteur pour le retrouver ici.",
            rowIdentifier: "author-row",
            people: Showcase.authorsPage(limit: 8, after: nil, order: .recent).items,
            order: .recent,
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}

#Preview("Favourites, none yet") {
    NavigationStack {
        PersonShelfPage<FollowedAuthor>(
            title: "Auteurs",
            failureTitle: "Auteurs indisponibles",
            noFavoritesTitle: "Aucun auteur préféré",
            noFavoritesMessage: "Touchez le cœur sur la page d’un auteur pour le retrouver ici.",
            rowIdentifier: "author-row",
            people: [],
            order: .loved,
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}

#Preview("Narrateurs") {
    NavigationStack {
        PersonShelfPage(
            title: "Narrateurs",
            failureTitle: "Narrateurs indisponibles",
            noFavoritesTitle: "Aucun narrateur préféré",
            noFavoritesMessage: "Touchez le cœur sur la page d’un narrateur pour le retrouver ici.",
            rowIdentifier: "narrator-row",
            people: Showcase.narratorsPage(limit: 8, after: nil, order: .recent).items,
            order: .recent,
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}
#endif
