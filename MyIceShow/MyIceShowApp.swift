import SwiftUI

@main
struct MyIceShowApp: App {
    var body: some Scene {
        WindowGroup {
            AppTabView()
                .preferredColorScheme(.light)
        }
    }
}
