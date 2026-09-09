import Foundation

/// Parses PlainLaunch's own custom URL scheme, used by the widget to hand a tap off to the app.
///
/// Format: `plainlaunch://open?target=<LaunchTarget rawValue>`
/// Example: `plainlaunch://open?target=phone`
public enum DeepLinkParser {
    public static let scheme = "plainlaunch"

    public static func parse(_ url: URL) -> LaunchTarget? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        guard url.host?.lowercased() == "open" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard let rawTarget = components.queryItems?.first(where: { $0.name == "target" })?.value else {
            return nil
        }
        return LaunchTarget(rawValue: rawTarget)
    }

    public static func url(for target: LaunchTarget) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "target", value: target.rawValue)]
        return components.url!
    }
}
