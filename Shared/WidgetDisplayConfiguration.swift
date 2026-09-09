import Foundation

/// Per-row visibility, order, and label. `Codable` so it round-trips through shared storage.
public struct WidgetItemSettings: Codable, Equatable, Identifiable, Sendable {
    public var target: LaunchTarget
    public var isEnabled: Bool
    public var customName: String?

    public var id: String { target.rawValue }

    public init(target: LaunchTarget, isEnabled: Bool = true, customName: String? = nil) {
        self.target = target
        self.isEnabled = isEnabled
        self.customName = customName
    }
}

public enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case leading, center, trailing
    public var id: String { rawValue }
}

public enum FontWeightOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case regular, medium, semibold, bold
    public var id: String { rawValue }
}

/// Everything the widget needs to render, and everything the app's customization screen edits.
/// Stored as JSON in the shared App Group container so both targets see the same values.
public struct WidgetDisplayConfiguration: Codable, Equatable, Sendable {
    public var items: [WidgetItemSettings]
    public var alignment: TextAlignmentOption
    public var fontSize: Double
    public var fontWeight: FontWeightOption
    public var lineSpacing: Double
    public var textColorHex: String
    public var backgroundColorHex: String

    public init(
        items: [WidgetItemSettings],
        alignment: TextAlignmentOption,
        fontSize: Double,
        fontWeight: FontWeightOption,
        lineSpacing: Double,
        textColorHex: String,
        backgroundColorHex: String
    ) {
        self.items = items
        self.alignment = alignment
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.lineSpacing = lineSpacing
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
    }

    public static let `default` = WidgetDisplayConfiguration(
        items: LaunchTarget.defaultOrder.map { WidgetItemSettings(target: $0) },
        alignment: .leading,
        fontSize: 28,
        fontWeight: .semibold,
        lineSpacing: 10,
        textColorHex: "#FFFFFF",
        backgroundColorHex: "#000000"
    )

    /// Rows to actually draw in the widget, already filtered and in user-chosen order.
    public var visibleItems: [WidgetItemSettings] {
        items.filter { $0.isEnabled }
    }

    /// Repairs a decoded configuration against the current `LaunchTarget` case list: adds any
    /// new target introduced by an app update (enabled, at the end) and drops any that were
    /// removed. Keeps old widget data forward/backward compatible without a migration step.
    public func reconciled() -> WidgetDisplayConfiguration {
        var result = self
        let known = Set(items.map(\.target))
        let missing = LaunchTarget.defaultOrder.filter { !known.contains($0) }
        result.items.append(contentsOf: missing.map { WidgetItemSettings(target: $0) })
        let validTargets = Set(LaunchTarget.allCases)
        result.items.removeAll { !validTargets.contains($0.target) }
        return result
    }
}
