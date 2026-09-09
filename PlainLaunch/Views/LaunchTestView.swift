import SwiftUI

struct LaunchTestView: View {
    @EnvironmentObject private var coordinator: LaunchCoordinator

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("test.intro")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .listRowBackground(Color.black)
                }
                Section {
                    ForEach(LaunchTarget.defaultOrder) { target in
                        row(for: target)
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.black.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle(String(localized: "tab.test"))
        }
        .navigationViewStyle(.stack)
    }

    private func row(for target: LaunchTarget) -> some View {
        let info = LaunchCatalog.info(for: target)
        return Button {
            coordinator.launch(target)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(target.localizedDefaultName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    if case .shortcut = info.primary {
                        Text("test.badge.shortcut")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.85)))
                    }
                }
                if let status = statusText(for: target) {
                    Text(status)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(Color.black)
    }

    private func statusText(for target: LaunchTarget) -> String? {
        guard let result = coordinator.lastResult[target] else { return nil }
        switch result {
        case .openedDirectly:
            return String(localized: "test.status.opened")
        case .openedViaShortcut(let name):
            return String(format: String(localized: "test.status.shortcutRan"), name)
        case .shortcutsAppUnavailable(let name):
            return String(format: String(localized: "test.status.shortcutMissing"), name)
        case .unavailable:
            return String(localized: "test.status.unavailable")
        }
    }
}
