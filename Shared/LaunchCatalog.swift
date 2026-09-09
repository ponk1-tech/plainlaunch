import Foundation

/// Central registry of how each `LaunchTarget` is opened. This is the only place that decides
/// launch methods; views and the coordinator just consume it.
///
/// Research summary (checked against Apple's public "Apple URL Scheme Reference" and current
/// App Store Review Guidelines at implementation time — see README "Launch methods" for sources
/// and dates):
///
/// - Phone: `tel:` is Apple's public documented scheme. With no phone number it is expected to
///   open the Phone app itself; confirmed on-device (see docs/verification.md). Shortcuts
///   fallback kept in case a future iOS version changes this behavior.
/// - Messages: `sms:` is Apple's public documented scheme for composing a message and reliably
///   opens the Messages app with no recipient supplied.
/// - Camera: Apple publishes no public URL scheme or Universal Link that opens the Camera app.
///   `AVFoundation` only lets an app use device cameras itself, not launch Camera.app. Shortcuts'
///   "Open App" action is Apple's own supported mechanism for this, so it is the primary (and
///   only) method.
/// - Music: `https://music.apple.com` is an Apple-owned domain with a registered
///   apple-app-site-association, so it is a genuine Universal Link — iOS hands off to the Music
///   app when installed instead of opening Safari.
/// - Podcasts: same reasoning via `https://podcasts.apple.com`.
/// - Soundcore: Anker publishes no public URL scheme for the soundcore app. Guessing one would
///   violate the "no private API / no guessed scheme" rule, so the only method is Shortcuts.
/// - Settings: `UIApplication.openSettingsURLString` only opens *this app's* settings page, not
///   the Settings app's root — using it to claim "opens Settings" would misrepresent the app to
///   both users and reviewers. No public API opens Settings' root screen, so Shortcuts is the
///   only method used in the App Store build. (`App-Prefs:`/`prefs:` exist only in
///   `ExperimentalLaunchMethod`, gated out of Release builds.)
public enum LaunchCatalog {
    public static func info(for target: LaunchTarget) -> LaunchTargetInfo {
        switch target {
        case .phone:
            return LaunchTargetInfo(
                target: .phone,
                primary: .url(URL(string: "tel:")!),
                fallback: .shortcut(name: ShortcutName.openPhone)
            )
        case .messages:
            return LaunchTargetInfo(
                target: .messages,
                primary: .url(URL(string: "sms:")!),
                fallback: nil
            )
        case .camera:
            return LaunchTargetInfo(
                target: .camera,
                primary: .shortcut(name: ShortcutName.openCamera),
                fallback: nil
            )
        case .music:
            return LaunchTargetInfo(
                target: .music,
                primary: .url(URL(string: "https://music.apple.com/")!),
                fallback: .shortcut(name: ShortcutName.openMusic)
            )
        case .podcasts:
            return LaunchTargetInfo(
                target: .podcasts,
                primary: .url(URL(string: "https://podcasts.apple.com/")!),
                fallback: .shortcut(name: ShortcutName.openPodcasts)
            )
        case .soundcore:
            return LaunchTargetInfo(
                target: .soundcore,
                primary: .shortcut(name: ShortcutName.openSoundcore),
                fallback: nil
            )
        case .settings:
            return LaunchTargetInfo(
                target: .settings,
                primary: .shortcut(name: ShortcutName.openSettings),
                fallback: nil
            )
        }
    }

    /// Targets whose *primary* method requires a user-created Shortcut before they work.
    public static var targetsRequiringShortcut: [LaunchTarget] {
        LaunchTarget.allCases.filter {
            if case .shortcut = info(for: $0).primary { return true }
            return false
        }
    }
}
