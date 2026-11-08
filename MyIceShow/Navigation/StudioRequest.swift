import Foundation

enum StudioDestination {
    case newShow
    case savedShow(SavedShow)
}

struct StudioRequest: Identifiable {
    let id = UUID()
    let destination: StudioDestination
}
