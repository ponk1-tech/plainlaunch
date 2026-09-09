import Foundation

/// The fixed set of destinations PlainLaunch can send the user to.
///
/// This list is intentionally small and hard-coded for the MVP: PlainLaunch does not (and, per
/// current iOS APIs, cannot) enumerate the apps installed on the device. Every case here maps to
/// something the user explicitly asked to be able to reach quickly from the widget.
public enum LaunchTarget: String, CaseIterable, Codable, Identifiable, Sendable {
    case phone
    case messages
    case camera
    case music
    case podcasts
    case soundcore
    case settings

    public var id: String { rawValue }

    /// Localization key for the default row label. Users may override this per target
    /// (see `WidgetDisplayConfiguration.ItemSettings.customName`).
    public var defaultNameKey: String {
        switch self {
        case .phone: return "target.phone"
        case .messages: return "target.messages"
        case .camera: return "target.camera"
        case .music: return "target.music"
        case .podcasts: return "target.podcasts"
        case .soundcore: return "target.soundcore"
        case .settings: return "target.settings"
        }
    }

    /// Stable ordering used the very first time the app runs (before any user customization).
    public static let defaultOrder: [LaunchTarget] = [
        .phone, .messages, .camera, .music, .podcasts, .soundcore, .settings,
    ]

    /// Localized label from the running target's own bundle (app or widget extension).
    public var localizedDefaultName: String {
        NSLocalizedString(defaultNameKey, bundle: .main, comment: "Default row label for \(rawValue)")
    }
}
