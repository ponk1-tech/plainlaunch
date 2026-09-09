import SwiftUI

/// The actual "black background, white text, no icons" list. Used by both the WidgetKit view
/// and the app's live preview in the customization screen, so what the user configures is
/// exactly what they see on the Home Screen.
public struct WidgetRowsView: View {
    let configuration: WidgetDisplayConfiguration
    let nameProvider: (LaunchTarget) -> String

    public init(configuration: WidgetDisplayConfiguration, nameProvider: @escaping (LaunchTarget) -> String) {
        self.configuration = configuration
        self.nameProvider = nameProvider
    }

    public var body: some View {
        let rows = configuration.visibleItems
        ZStack {
            Color(hex: configuration.backgroundColorHex, fallback: .black)
                .ignoresSafeArea()
            VStack(alignment: configuration.alignment.swiftUIAlignment, spacing: configuration.lineSpacing) {
                if rows.isEmpty {
                    Text("widget.empty", bundle: .main)
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(Color(hex: configuration.textColorHex, fallback: .white).opacity(0.6))
                } else {
                    ForEach(rows) { item in
                        Text(item.customName?.isEmpty == false ? item.customName! : nameProvider(item.target))
                            .font(.system(size: configuration.fontSize, weight: configuration.fontWeight.swiftUIWeight, design: .default))
                            .foregroundColor(Color(hex: configuration.textColorHex, fallback: .white))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: configuration.alignment.frameAlignment)
            .multilineTextAlignment(configuration.alignment.swiftUITextAlignment)
            .padding(20)
        }
    }
}
