import SwiftUI

@main
struct PlainLaunchApp: App {
    @StateObject private var coordinator = LaunchCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    if let target = DeepLinkParser.parse(url) {
                        coordinator.launch(target)
                    }
                }
        }
    }
}
