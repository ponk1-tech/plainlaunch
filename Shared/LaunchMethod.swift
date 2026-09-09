import Foundation

/// How PlainLaunch attempts to open a given `LaunchTarget`.
///
/// iOS gives third-party apps no supported way to launch an arbitrary other app by bundle
/// identifier. Every case below is either:
///  1. An Apple-documented public URL scheme (`tel:`, `sms:`),
///  2. A Universal Link into an Apple-owned domain that hands off to the matching first-party
///     app when it is installed (`music.apple.com`, `podcasts.apple.com`), or
///  3. The Shortcuts app's public `shortcuts://run-shortcut` URL scheme, used to run a
///     user-created shortcut whose only action is Apple's own "Open App" action.
///
/// No private/undocumented URL scheme (e.g. `App-Prefs:`, `prefs:`, `camera://`) is used here.
/// Those are isolated in `ExperimentalLaunchMethod` and are never compiled into the App Store
/// build. See `docs/app-review-notes.md` and the README "Launch methods" section for the full
/// rationale per target.
public enum LaunchMethod: Equatable, Sendable {
    /// Open a public, documented URL directly via `UIApplication.open`.
    case url(URL)
    /// Ask the Shortcuts app to run a user-created shortcut by name.
    case shortcut(name: String)
    /// No safe, public launch method exists; PlainLaunch will not attempt anything.
    case unsupported
}

/// Describes one destination end-to-end: its primary method, and what to try if that fails.
public struct LaunchTargetInfo: Equatable, Sendable {
    public let target: LaunchTarget
    public let primary: LaunchMethod
    public let fallback: LaunchMethod?

    public init(target: LaunchTarget, primary: LaunchMethod, fallback: LaunchMethod? = nil) {
        self.target = target
        self.primary = primary
        self.fallback = fallback
    }
}

/// The name Shortcuts fallback shortcuts must use, per target, if the user chooses to create
/// them. Centralized here so the app's help UI and the catalog never drift apart.
public enum ShortcutName {
    public static let openPhone = "Open Phone"
    public static let openCamera = "Open Camera"
    public static let openSoundcore = "Open Soundcore"
    public static let openSettings = "Open Settings"
    public static let openMusic = "Open Music"
    public static let openPodcasts = "Open Podcasts"
}
