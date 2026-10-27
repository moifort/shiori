import SwiftUI

/// The series screen of the Library tab, connected: owns the view model,
/// pushes the saga a card or a poster opens, and the sagas set aside.
struct SeriesShelfScreen: View {
    var client: SeriesClient = .live

    @State private var viewModel: SeriesShelfViewModel
    @State private var openSeries: SeriesDestinationID?
    @State private var showsSetAside = false

    init(filter: SeriesShelfFilter = .all, client: SeriesClient = .live) {
        self.client = client
        _viewModel = State(initialValue: SeriesShelfViewModel(client: client, filter: filter))
    }

    var body: some View {
        SeriesShelfPage(
            upNext: viewModel.upNext,
            releases: viewModel.releases,
            filters: viewModel.filters,
            filter: viewModel.filter,
            series: viewModel.filtered,
            hasSetAside: !viewModel.setAside.isEmpty,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        ) { action in
            switch action {
            case let .openSeries(saga): openSeries = SeriesDestinationID(id: saga.seriesId)
            case let .selectFilter(filter): withAnimation(.smooth) { viewModel.filter = filter }
            case .openSetAside: showsSetAside = true
            case .refresh: Task { await viewModel.load() }
            }
        }
        .searchesLibrary(String(localized: "Séries"))
        .pushesDetail(item: $openSeries) { SeriesScreen(seriesId: $0.id) }
        .navigationDestination(isPresented: $showsSetAside) {
            SetAsideSeriesPage(
                series: viewModel.setAside,
                isLoading: viewModel.isLoading,
                onOpen: { openSeries = SeriesDestinationID(id: $0.seriesId) },
                onFollow: { saga in Task { await viewModel.follow(saga) } }
            )
            .closesAsPushed()
        }
        .task { await viewModel.loadOnAppear() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }
}

/// The sagas set aside, pushed on their own from the Library's entry screen.
struct SetAsideSeriesScreen: View {
    var client: SeriesClient = .live

    @State private var viewModel: SeriesShelfViewModel
    @State private var openSeries: SeriesDestinationID?

    init(client: SeriesClient = .live) {
        self.client = client
        _viewModel = State(initialValue: SeriesShelfViewModel(client: client))
    }

    var body: some View {
        SetAsideSeriesPage(
            series: viewModel.setAside,
            isLoading: viewModel.isLoading,
            onOpen: { openSeries = SeriesDestinationID(id: $0.seriesId) },
            onFollow: { saga in Task { await viewModel.follow(saga) } }
        )
        .pushesDetail(item: $openSeries) { SeriesScreen(seriesId: $0.id) }
        .task { await viewModel.loadOnAppear() }
    }
}

/// The saga a card opens.
struct SeriesDestinationID: Identifiable, Hashable {
    let id: String
}

#if DEBUG
#Preview {
    NavigationStack {
        SeriesShelfScreen(client: .preview)
    }
}
#endif
