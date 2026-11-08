import SwiftUI

private enum AppTab: Hashable {
    case home
    case studio
    case shows
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showLibrary = ShowLibrary()
    @State private var studioRequest: StudioRequest?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView(
                    recentShows: Array(showLibrary.shows.prefix(3)),
                    hasLibraryError: showLibrary.loadError != nil,
                    onCreate: { openStudio(.newShow) },
                    onContinue: { selectedTab = .studio },
                    onShowLibrary: { selectedTab = .shows },
                    onOpenShow: { openStudio(.savedShow($0)) }
                )
            }
            Tab("Studio", systemImage: "wand.and.stars", value: AppTab.studio) {
                StudioView(
                    showLibrary: showLibrary,
                    request: studioRequest,
                    isActive: selectedTab == .studio,
                    onRequestHandled: { studioRequest = nil },
                    onShowLibrary: { selectedTab = .shows }
                )
            }
            Tab("Shows", systemImage: "rectangle.stack", value: AppTab.shows) {
                ShowLibraryView(
                    shows: showLibrary.shows,
                    loadError: showLibrary.loadError,
                    onRetry: { showLibrary.reload() },
                    onCreate: { openStudio(.newShow) },
                    onOpen: { openStudio(.savedShow($0)) }
                )
            }
        }
        .tint(StudioTheme.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.white, for: .tabBar)
    }

    private func openStudio(_ destination: StudioDestination) {
        studioRequest = StudioRequest(destination: destination)
        selectedTab = .studio
    }
}
