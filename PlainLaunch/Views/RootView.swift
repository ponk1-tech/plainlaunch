import SwiftUI

struct RootView: View {
    // Which tab opens first. Always 0 (About) for real users. `scripts/screenshots.sh` overrides
    // it per screenshot via `simctl launch <device> <bundle> -QATab N`, which lands here through
    // the standard NSUserDefaults argument domain — no separate debug build needed.
    @State private var selection = UserDefaults.standard.integer(forKey: "QATab")

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label(String(localized: "tab.home"), systemImage: "text.alignleft") }
                .tag(0)

            WidgetGuideView()
                .tabItem { Label(String(localized: "tab.widget"), systemImage: "square.grid.2x2") }
                .tag(1)

            LaunchTestView()
                .tabItem { Label(String(localized: "tab.test"), systemImage: "checkmark.circle") }
                .tag(2)

            CustomizeView()
                .tabItem { Label(String(localized: "tab.customize"), systemImage: "slider.horizontal.3") }
                .tag(3)
        }
        .tint(.white)
    }
}
