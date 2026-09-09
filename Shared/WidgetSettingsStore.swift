import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The App Group both targets are entitled to. Registered via the App Store Connect API
/// (`APP_GROUPS` bundle ID capability) and materialized by Xcode's automatic signing.
public enum AppGroup {
    public static let identifier = "group.com.ponk1tech.plainlaunch"
}

/// Reads and writes `WidgetDisplayConfiguration` to the shared App Group container.
///
/// If the App Group container isn't available for any reason (e.g. entitlement not yet
/// provisioned), every read falls back to `.default` and writes are silently skipped — the app
/// and widget must never crash over missing shared storage.
public final class WidgetSettingsStore {
    public static let shared = WidgetSettingsStore()

    private static let storageKey = "widgetConfiguration.v1"
    private let defaults: UserDefaults?

    public init(suiteName: String = AppGroup.identifier) {
        self.defaults = UserDefaults(suiteName: suiteName)
    }

    public func load() -> WidgetDisplayConfiguration {
        guard let defaults, let data = defaults.data(forKey: Self.storageKey) else {
            return .default
        }
        guard let decoded = try? JSONDecoder().decode(WidgetDisplayConfiguration.self, from: data) else {
            return .default
        }
        return decoded.reconciled()
    }

    @discardableResult
    public func save(_ configuration: WidgetDisplayConfiguration) -> Bool {
        guard let defaults else { return false }
        guard let data = try? JSONEncoder().encode(configuration) else { return false }
        defaults.set(data, forKey: Self.storageKey)
        reloadWidgetTimelines()
        return true
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
