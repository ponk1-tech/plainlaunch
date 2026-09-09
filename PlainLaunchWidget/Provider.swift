import WidgetKit

/// The widget's only piece of state: the shared configuration written by the app.
/// Everything else (alignment, colors, which rows show) lives in `WidgetDisplayConfiguration` itself.
struct PlainLaunchEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetDisplayConfiguration
}

/// iOS 16-compatible `TimelineProvider` (not `AppIntentTimelineProvider`, which requires iOS 17).
/// The widget has no per-instance configuration of its own — everything is driven by the shared
/// `WidgetDisplayConfiguration` the app writes to the App Group — so `StaticConfiguration` is enough.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PlainLaunchEntry {
        PlainLaunchEntry(date: Date(), configuration: .default)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlainLaunchEntry) -> Void) {
        let configuration = context.isPreview ? .default : WidgetSettingsStore.shared.load()
        completion(PlainLaunchEntry(date: Date(), configuration: configuration))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlainLaunchEntry>) -> Void) {
        let entry = PlainLaunchEntry(date: Date(), configuration: WidgetSettingsStore.shared.load())
        // Content only changes when the user edits settings in the app, and the app already
        // calls `WidgetCenter.shared.reloadAllTimelines()` on every save — so there is nothing
        // to refresh on a timer. `.never` avoids waking the widget for no reason.
        completion(Timeline(entries: [entry], policy: .never))
    }
}
