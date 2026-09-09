# App Review notes

## Guideline 2.5.8 ("alternate desktop/home screen environments")

> Apps that create alternate desktop/home screen environments or simulate multi-app widget
> experiences are not appropriate for the App Store.

PlainLaunch does not do this. Concretely:

- It ships one ordinary `WidgetKit` widget (`StaticConfiguration` + `TimelineProvider`), added
  through the normal system widget gallery, the same as any other widget.
- It does not run as, replace, or simulate `SpringBoard`. There is no full-screen "fake home
  screen" mode, no app that mimics the system Home Screen's layout/behavior, and no attempt to
  be the first thing the user sees on boot/unlock.
- The widget shows plain text rows the user configured, each linking (via the app's own
  `plainlaunch://` scheme) to one specific, named action. It is a shortcut list, functionally
  no different in kind from widgets like Shortcuts' or a bookmarks widget — just styled plainly.
- The app's own description (see `AppStore/metadata.json`) describes it exactly this way: "a
  Home Screen widget", never "a new Home Screen" or "replaces your Home Screen".

The user's own plan to later use Apple Configurator / MDM supervision to restrict a personal
iPhone to a small set of allowed apps is a separate, out-of-band device-management step the user
performs on their own hardware with their own Apple ID — it is not implemented by, triggered by,
or dependent on this app, and is not part of what's being submitted to the App Store.

## Camera / Settings / Soundcore via Shortcuts

Guideline 2.5.1 asks apps to use public APIs. PlainLaunch does: `shortcuts://run-shortcut` is
Apple's own public URL scheme for the Shortcuts app, and the shortcuts it runs use Shortcuts'
built-in "Open App" action — nothing PlainLaunch does here touches a private API or an
undocumented scheme. `Shared/ExperimentalLaunchMethod.swift` exists specifically to keep
undocumented schemes (`App-Prefs:`, `camera://`) out of anything that ships; it is not referenced
by `LaunchCatalog`, and there is a unit test (`LaunchCatalogTests.test_noExperimentalOrPrivateSchemesInTheCatalog`)
asserting that.

## Third-party app dependency (Anker soundcore)

The "Soundcore" entry works whether or not the Anker soundcore app is installed:

- If the user hasn't created the `Open Soundcore` shortcut yet, tapping it opens the Shortcuts
  app (or, if Shortcuts itself is unavailable, shows an in-app status message) — no crash.
- PlainLaunch never checks whether Anker soundcore specifically is installed; it has no way to,
  and doesn't need to — the shortcut itself is what would fail gracefully inside Shortcuts if the
  target app is missing.

## How to review

1. Launch the app — the **About** tab explains what it is (and, explicitly, what it isn't).
2. **Widget** tab — the exact steps to add the widget to a Home Screen.
3. **Test** tab — every one of the 7 launch targets can be exercised without ever adding the
   widget. Tapping a name shows a plain-language status line explaining what happened. Items
   that need a Shortcut are labeled "Needs Shortcut" before you even tap them.
4. **Customize** tab — live preview of exactly what the widget renders, using the same view code
   the widget itself uses (`Shared/WidgetRowsView.swift`).

No login, no test account, no network connection is needed to review any of this.
