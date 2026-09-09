import SwiftUI
import UIKit

extension Color {
    /// Parses `#RRGGBB` (or `RRGGBB`) hex strings, as stored in `WidgetDisplayConfiguration`.
    /// Falls back to `fallback` for anything malformed instead of crashing.
    init(hex: String, fallback: Color = .white) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else {
            self = fallback
            return
        }
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    /// Best-effort round trip back to `#RRGGBB`, using UIKit's color space conversion so any
    /// `Color` the system `ColorPicker` hands back (which may be in a wide-gamut space) still
    /// produces a plain sRGB hex string.
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return "#FFFFFF" }
        return String(
            format: "#%02X%02X%02X",
            Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded())
        )
    }
}

extension TextAlignmentOption {
    var swiftUIAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var swiftUITextAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

extension FontWeightOption {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}
