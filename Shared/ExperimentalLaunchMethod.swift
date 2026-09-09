import Foundation

/// Undocumented URL schemes that are commonly discussed online (`App-Prefs:`, `prefs:`,
/// `camera://`, ...) but are **not** published by Apple as public API. Apple can change or block
/// them at any time, and relying on them is a real App Review risk (they resemble private-API
/// use even though they are just URLs, since the behavior they trigger is undocumented).
///
/// PlainLaunch never uses these in the App Store build. `LaunchCatalog` (the source of truth for
/// the shipping app) does not reference this type at all. It exists only so a developer building
/// a local/experimental configuration can opt in explicitly and knowingly.
///
/// Do not wire this into `LaunchCoordinator` for Release builds.
public enum ExperimentalLaunchMethod {
    /// Community-documented, Apple-unsupported scheme that opens the Settings app root on some
    /// iOS versions. Never used in the shipping app. See README "Experimental (not shipped)".
    public static let settingsRoot = URL(string: "App-Prefs:root")

    /// Community-documented, Apple-unsupported scheme sometimes reported to open Camera.app.
    /// Never used in the shipping app.
    public static let cameraRoot = URL(string: "camera://")

    /// Always false in this codebase; flips on only in a local experimental scheme/target that
    /// is not part of the App Store archive.
    public static let isEnabled = false
}
