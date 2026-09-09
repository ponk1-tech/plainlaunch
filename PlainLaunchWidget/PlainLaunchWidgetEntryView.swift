import SwiftUI
import WidgetKit

/// The actual widget face: black background, left-aligned (by default) white text rows, no
/// icons. Each row is its own `Link` so tapping a single name opens only that target — WidgetKit
/// has supported multiple independent tap targets inside one widget since iOS 16.
struct PlainLaunchWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        let configuration = entry.configuration
        let rows = configuration.visibleItems
        let textColor = Color(hex: configuration.textColorHex, fallback: .white)

        Group {
            if #available(iOS 17.0, *) {
                content(rows: rows, configuration: configuration, textColor: textColor)
                    .containerBackground(Color(hex: configuration.backgroundColorHex, fallback: .black), for: .widget)
            } else {
                content(rows: rows, configuration: configuration, textColor: textColor)
                    .background(Color(hex: configuration.backgroundColorHex, fallback: .black))
            }
        }
    }

    @ViewBuilder
    private func content(rows: [WidgetItemSettings], configuration: WidgetDisplayConfiguration, textColor: Color) -> some View {
        VStack(alignment: configuration.alignment.swiftUIAlignment, spacing: configuration.lineSpacing) {
            if rows.isEmpty {
                Text("widget.empty")
                    .font(.system(size: 14))
                    .foregroundColor(textColor.opacity(0.6))
                    .multilineTextAlignment(configuration.alignment.swiftUITextAlignment)
            } else {
                ForEach(rows) { item in
                    Link(destination: DeepLinkParser.url(for: item.target)) {
                        Text(item.customName?.isEmpty == false ? item.customName! : item.target.localizedDefaultName)
                            .font(.system(size: configuration.fontSize, weight: configuration.fontWeight.swiftUIWeight, design: .default))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: configuration.alignment.frameAlignment)
        .padding(20)
    }
}
