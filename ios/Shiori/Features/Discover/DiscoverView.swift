import SwiftUI

/// The Découvrir tab: the books the reader read in another language, now out
/// or coming out in theirs — printed, and recorded for a reader connected to
/// Audible. Read through one format at a time, picked in the toolbar and kept
/// between visits. One row per saga or per book on its own; swiping one away
/// says "not interested" for good.
///
/// The server looks again every day. Until the first time, the tab offers to
/// look now; after that, once a day at most.
struct DiscoverView: View {
    @State private var feed: DiscoverFeed?
    @State private var isLoading = true
    @State private var isPreparing = false
    @State private var errorMessage: String?
    @State private var openTranslation: Translation?
    @AppStorage("discover.format") private var format: TranslationFormat = .book

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Découvrir")
                .toolbar { toolbar }
                .sheet(item: $openTranslation) { translation in
                    TranslationView(translation: translation, format: format) {
                        Task { await dismiss(translation) }
                    }
                }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && feed == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, feed == nil {
            EmptyStateView.failure("Découvrir indisponible", message: errorMessage) { await load() }
        } else if let whole = feed {
            let feed = whole.narrowed(to: format)
            List {
                if feed.preparedAt == nil {
                    Section { prepareCard }
                } else if feed.isEmpty {
                    Section {
                        EmptyStateView(
                            systemImage: format == .audiobook ? "headphones" : "character.book.closed",
                            title: "Aucune traduction pour l'instant",
                            message: format == .audiobook
                                ? "Les livres audio en français des livres que vous lisez dans une autre langue apparaîtront ici. Ils ne sont proposés que si vous avez connecté Audible."
                                : "Les livres que vous lisez dans une autre langue apparaîtront ici dès qu'ils sortent, ou sont annoncés, en français."
                        )
                    }
                    .listRowBackground(Color.clear)
                }
                if !feed.upcoming.isEmpty {
                    Section {
                        ForEach(feed.upcoming) { row($0) }
                    } header: {
                        Text("Bientôt en français")
                    } footer: {
                        Label("Vous recevrez une notification le jour de la sortie.", systemImage: "bell")
                    }
                }
                if !feed.available.isEmpty {
                    Section("Déjà disponibles en français") {
                        ForEach(feed.available) { row($0) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await load() }
        }
    }

    /// The two formats as the Library tab lays out its views: icons on the
    /// left, the one picked in the tint.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            ForEach(TranslationFormat.allCases) { item in
                Button {
                    format = item
                } label: {
                    Label(item.filterLabel, systemImage: item.symbol)
                }
                .labelStyle(.iconOnly)
                .tint(format == item ? .accentColor : .primary)
                .accessibilityIdentifier("discover-format-\(item.rawValue)")
            }
        }
        if let feed, feed.preparedAt != nil, feed.canRefresh {
            ToolbarItem(placement: .primaryAction) {
                if isPreparing {
                    ProgressView()
                } else {
                    Button {
                        Task { await prepare() }
                    } label: {
                        Label("Chercher à nouveau", systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("discover-refresh")
                }
            }
        }
    }

    private var prepareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Vos lectures, en français", systemImage: "character.book.closed").font(.headline)
            Text("Shiori cherche, pour chaque livre que vous avez lu dans une autre langue, sa traduction française : déjà parue ou annoncée, en livre, et en livre audio si vous avez connecté Audible. Cela prend une minute.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                Task { await prepare() }
            } label: {
                HStack {
                    if isPreparing { ProgressView().tint(.white) }
                    Text(isPreparing ? "Recherche en cours…" : "Chercher les traductions")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPreparing)
            .accessibilityIdentifier("discover-prepare")
        }
        .padding(.vertical, 6)
    }

    private func row(_ translation: Translation) -> some View {
        Button {
            openTranslation = translation
        } label: {
            TranslationRow(translation: translation)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await dismiss(translation) }
            } label: {
                Label("Pas intéressé", systemImage: "eye.slash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await dismiss(translation) }
            } label: {
                Label("Pas intéressé", systemImage: "eye.slash")
            }
        }
        .accessibilityIdentifier("discover-row")
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        do {
            feed = try await DiscoverAPI.feed()
            errorMessage = nil
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
        await askForAlertsIfWorthIt()
    }

    private func prepare() async {
        isPreparing = true
        defer { isPreparing = false }
        do {
            feed = try await DiscoverAPI.refresh()
            errorMessage = nil
        } catch {
            errorMessage = reportError(error)
        }
        await askForAlertsIfWorthIt()
    }

    /// The alert is on by default, but the system asks once: the first time
    /// the tab has a release to announce, which is when saying yes means
    /// something. Asked once, the system never shows it again.
    private func askForAlertsIfWorthIt() async {
        guard let feed, !feed.upcoming.isEmpty else { return }
        _ = await PushRegistrar.shared.requestPermission()
    }

    private func dismiss(_ translation: Translation) async {
        withAnimation { feed?.remove(key: translation.key) }
        do {
            try await DiscoverAPI.dismiss(key: translation.key)
        } catch {
            errorMessage = reportError(error)
            await load()
        }
    }
}

/// One work on the tab: its cover, its French title, what it is, and when the
/// next edition comes out.
private struct TranslationRow: View {
    let translation: Translation

    var body: some View {
        HStack(spacing: 12) {
            BookCover(book: translation.book, width: 44, showsFormatBadge: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(translation.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let next = translation.nextDate {
                ReleaseDateBadge(date: next)
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }

    private var subtitle: String {
        if translation.isSeries {
            if let next = translation.editions.first(where: \.isUpcoming) {
                let volume = next.volume.map { String(localized: "Tome \($0)") } ?? next.title
                return "\(volume), \(ReleaseDateText.phrase(next.date ?? ""))"
            }
            return TranslationView.availableVolumes(translation.editions)
        }
        let language = translation.originalLanguage.label.lowercased()
        return translation.title == translation.originalTitle
            ? String(localized: "Lu en \(language)")
            : String(localized: "Lu en \(language) : \(translation.originalTitle)")
    }
}

/// A release date in a sentence: "le 19 févr. 2027", "en mars 2027", "en
/// 2027" — as precisely as it was announced.
enum ReleaseDateText {
    /// The last day a date can mean, to put "2027" after "2027-02-19".
    static func lastDay(_ date: String) -> String {
        switch date.count {
        case 10: date
        case 7: date + "-31"
        default: date + "-12-31"
        }
    }

    static func phrase(_ date: String) -> String {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts.first
        components.month = parts.count > 1 ? parts[1] : 1
        components.day = parts.count > 2 ? parts[2] : 1
        guard let day = Calendar.current.date(from: components) else { return date }
        switch parts.count {
        case 3: return String(localized: "le \(day.formatted(.dateTime.day().month(.abbreviated).year()))")
        case 2: return String(localized: "en \(day.formatted(.dateTime.month(.wide).year()))")
        default: return String(localized: "en \(String(parts.first ?? 0))")
        }
    }
}

/// A release date as a small calendar leaf: the day over the month, or the
/// month over the year, or the year alone — as precisely as it was announced.
struct ReleaseDateBadge: View {
    let date: String

    var body: some View {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        VStack(spacing: 0) {
            Text(verbatim: top(parts)).font(.subheadline.weight(.semibold))
            Text(verbatim: bottom(parts)).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 44)
        .padding(.vertical, 4)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private func month(_ number: Int) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        return (1...12).contains(number) ? symbols[number - 1] : ""
    }

    private func top(_ parts: [Int]) -> String {
        switch parts.count {
        case 3: "\(parts[2])"
        case 2: month(parts[1])
        default: parts.first.map(String.init) ?? ""
        }
    }

    private func bottom(_ parts: [Int]) -> String {
        switch parts.count {
        case 3: month(parts[1])
        case 2: String(parts[0])
        default: ""
        }
    }
}

#Preview {
    DiscoverView()
}


