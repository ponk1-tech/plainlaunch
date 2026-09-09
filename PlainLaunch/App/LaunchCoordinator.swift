import Foundation
import UIKit

/// Executes a `LaunchTarget` using the method(s) from `LaunchCatalog`, and remembers what
/// happened so the in-app "test each target" screen can show real status instead of guessing.
///
/// Important limitation this type is honest about: when the method is `.shortcut`, iOS only
/// tells us whether the *Shortcuts app* opened, not whether the named shortcut existed or
/// whether it successfully opened the target app. There is no public API for that. So
/// `.openedViaShortcut` is reported as a best-effort outcome, not a confirmed success.
@MainActor
public final class LaunchCoordinator: ObservableObject {
    public enum LaunchResult: Equatable {
        /// A public URL (tel:, sms:, or a Universal Link) was opened directly and iOS confirmed it.
        case openedDirectly
        /// Asked Shortcuts to run the named shortcut. Whether the target app actually opened
        /// depends on whether the user has created that shortcut (see `docs/shortcuts.md`).
        case openedViaShortcut(name: String)
        /// The Shortcuts app itself is unavailable, so the fallback couldn't even be attempted.
        case shortcutsAppUnavailable(name: String)
        /// The direct URL failed and there is no fallback for this target.
        case unavailable
    }

    @Published public private(set) var lastResult: [LaunchTarget: LaunchResult] = [:]

    private let application: URLOpening

    public init(application: URLOpening) {
        self.application = application
    }

    /// Convenience for real app use; kept separate from the designated init above because a
    /// `@MainActor`-isolated default *parameter value* (as opposed to something evaluated in the
    /// init's body) is technically evaluated in a nonisolated context under Swift's concurrency
    /// checker, which `UIApplication.shared` cannot satisfy.
    public convenience init() {
        self.init(application: UIApplication.shared)
    }

    public func launch(_ target: LaunchTarget) {
        let info = LaunchCatalog.info(for: target)
        attempt(method: info.primary, target: target, fallback: info.fallback)
    }

    private func attempt(method: LaunchMethod, target: LaunchTarget, fallback: LaunchMethod?) {
        switch method {
        case .url(let url):
            application.open(url, options: [:]) { [weak self] success in
                // UIApplication.open's completion handler is documented to always be called on
                // the main thread; `@Sendable` on the protocol requirement (needed to match
                // UIKit's own signature under Swift 6 concurrency checking) just means the
                // compiler can't see that, so we assert it explicitly instead of hopping via
                // Task, which would make `.openedDirectly` observable a beat later than the
                // actual UIApplication call.
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if success {
                        self.record(.openedDirectly, for: target)
                    } else if let fallback {
                        self.attempt(method: fallback, target: target, fallback: nil)
                    } else {
                        self.record(.unavailable, for: target)
                    }
                }
            }
        case .shortcut(let name):
            guard let shortcutsBase = URL(string: "shortcuts://"),
                  application.canOpenURL(shortcutsBase),
                  let runURL = Self.runShortcutURL(name: name) else {
                record(.shortcutsAppUnavailable(name: name), for: target)
                return
            }
            application.open(runURL, options: [:]) { [weak self] success in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.record(success ? .openedViaShortcut(name: name) : .shortcutsAppUnavailable(name: name), for: target)
                }
            }
        case .unsupported:
            record(.unavailable, for: target)
        }
    }

    static func runShortcutURL(name: String) -> URL? {
        var components = URLComponents(string: "shortcuts://run-shortcut")
        components?.queryItems = [URLQueryItem(name: "name", value: name)]
        return components?.url
    }

    private func record(_ result: LaunchResult, for target: LaunchTarget) {
        lastResult[target] = result
    }
}

/// Narrow protocol over `UIApplication` so `LaunchCoordinator` is unit-testable without UIKit.
@MainActor
public protocol URLOpening {
    func canOpenURL(_ url: URL) -> Bool
    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completionHandler: (@Sendable (Bool) -> Void)?)
}

extension UIApplication: URLOpening {}
