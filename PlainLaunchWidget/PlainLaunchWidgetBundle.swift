import SwiftUI
import WidgetKit

struct PlainLaunchWidget: Widget {
    let kind: String = "PlainLaunchWidget"

    // `.contentMarginsDisabled()` (iOS 17+) is intentionally not used: `WidgetConfiguration`'s
    // result builder (unlike `ViewBuilder`) does not allow two branches of an `if #available` to
    // resolve to different opaque types, so there is no clean per-OS-version fork here. The
    // default system margins are an acceptable tradeoff for iOS 16 compatibility; the
    // background-fill difference between `.background()` (16) and `.containerBackground()` (17+)
    // is instead handled per-view, inside `PlainLaunchWidgetEntryView`, where `ViewBuilder` does
    // support branching.
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PlainLaunchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.displayName"))
        .description(String(localized: "widget.description"))
        .supportedFamilies([.systemLarge, .systemMedium])
    }
}

@main
struct PlainLaunchWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlainLaunchWidget()
    }
}
