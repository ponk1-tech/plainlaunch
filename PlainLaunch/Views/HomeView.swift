import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("PlainLaunch")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)

                    Text("home.tagline")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.85))

                    Divider().overlay(Color.white.opacity(0.2))

                    section(titleKey: "home.what.title", bodyKey: "home.what.body")
                    section(titleKey: "home.notALauncher.title", bodyKey: "home.notALauncher.body")
                    section(titleKey: "home.privacy.title", bodyKey: "home.privacy.body")

                    Spacer(minLength: 12)
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "tab.home"))
        }
        .navigationViewStyle(.stack)
    }

    private func section(titleKey: LocalizedStringKey, bodyKey: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleKey)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text(bodyKey)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}
