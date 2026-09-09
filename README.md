# PlainLaunch

A minimal, text-only Home Screen widget for iPhone. Black background, white text, no icons — a
short list of app names you tap to open them. Built for a simpler phone (an iPhone 8, in
particular), without replacing iOS or the Home Screen itself.

PlainLaunch is a **Home Screen widget utility**, not an alternate desktop/launcher environment.
See [App Review Guideline 2.5.8](https://developer.apple.com/app-store/review/guidelines/#2.5.8)
context in `docs/app-review-notes.md` for why this app does not fall under that guideline.

## Contents

- [Architecture](#architecture)
- [Requirements](#requirements)
- [Build](#build)
- [Run on iPhone 8 (or any device)](#run-on-a-real-iphone)
- [Add the widget](#add-the-widget)
- [Launch methods per target](#launch-methods-per-target)
- [Shortcuts fallback](#shortcuts-fallback)
- [Customization](#customization)
- [Tests](#tests)
- [Privacy](#privacy)
- [App Store release](#app-store-release)
- [App Store Connect API setup](#app-store-connect-api-setup)
- [Known limitations](#known-limitations)

## Architecture

```
PlainLaunch/                 iOS app (SwiftUI, iOS 16+)
  App/                       App entry point, deep link handling, LaunchCoordinator
  Views/                     About / Widget guide / Test / Customize tabs
  Resources/                 Assets.xcassets (App Icon), Localizable.strings (ja, en)
PlainLaunchWidget/            WidgetKit extension (StaticConfiguration + TimelineProvider,
                              iOS 16-compatible; iOS 17's containerBackground/contentMarginsDisabled
                              are used only behind `if #available(iOS 17, *)`)
Shared/                       Code compiled into BOTH targets:
  LaunchTarget.swift           enum of the 7 fixed destinations
  LaunchMethod.swift           how a target is opened (.url / .shortcut / .unsupported)
  LaunchCatalog.swift          the actual mapping — the one source of truth for what ships
  ExperimentalLaunchMethod.swift  undocumented schemes, isolated, NOT used by LaunchCatalog
  DeepLinkParser.swift          parses `plainlaunch://open?target=<id>`
  WidgetDisplayConfiguration.swift  Codable model for widget appearance/content
  WidgetSettingsStore.swift     App Group-backed read/write of that model
  WidgetRowsView.swift          the actual black/white row list, shared by widget + in-app preview
PlainLaunchTests/              Unit tests for all of the above (no UIKit/WidgetKit dependency
                               needed for the pure-logic pieces)
project.yml                    XcodeGen project spec (the .xcodeproj is generated, not committed)
docs/                          Privacy Policy / Support / landing page (GitHub Pages), ja + en
AppStore/                      metadata.json (App Store text content) + generated screenshots
scripts/, Makefile              Build/archive/upload/TestFlight/submit automation
```

### Why a widget, not a "launcher app"

WidgetKit gives third-party apps no supported way to launch an arbitrary other app directly.
PlainLaunch's widget rows are `Link`s to PlainLaunch's own `plainlaunch://open?target=<id>` URL
scheme; PlainLaunch (the app) receives that via `onOpenURL`, resolves it through
`LaunchCatalog`, and calls `UIApplication.open` on either a public URL or (for three targets that
have no public open method) asks the Shortcuts app to run a user-created shortcut.

```
Widget row (Link) → plainlaunch://open?target=X → PlainLaunchApp.onOpenURL
  → LaunchCoordinator.launch(X) → LaunchCatalog.info(for: X) → UIApplication.open(...)
```

## Requirements

- Xcode 16+ (developed/verified with Xcode 26.2)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- iOS 16.0+ deployment target, iPhone only (`TARGETED_DEVICE_FAMILY = 1`; no iPad/Mac/visionOS/
  watchOS)
- No third-party Swift packages, no CocoaPods, no fastlane — plain `xcodebuild` + small scripts,
  by design (see `docs/release.md` for the reasoning).

## Build

```sh
xcodegen generate      # generates PlainLaunch.xcodeproj (not committed — regenerate anytime)
make build             # Debug build for the Simulator
make test              # Unit tests
```

Or open `PlainLaunch.xcodeproj` in Xcode after `xcodegen generate`.

## Run on a real iPhone

```sh
./scripts/device.sh install   # build + install on whichever iPhone is currently paired
./scripts/device.sh launch    # ...and launch it
./scripts/device.sh logs      # stream console logs
```

The script auto-detects the connected device via `xcrun devicectl` and uses
`-authenticationKeyPath`/`-authenticationKeyID`/`-authenticationKeyIssuerID` (the App Store
Connect API key — see below) for automatic signing, so no Xcode-signed-in Apple ID is required.

If the device shows `The developer disk image could not be mounted`, that's iOS asking for a
one-time human step, not a build problem: connect the iPhone via **USB** (not just Wi-Fi),
**unlock it**, tap **Trust This Computer** if asked, and make sure **Developer Mode** is on
(Settings > Privacy & Security > Developer Mode). Re-run the script after that.

## Add the widget

Home Screen → touch and hold an empty area → **+** → search "PlainLaunch" → choose **Large** →
Add Widget. (Same flow the in-app "Widget" tab walks through.)

## Launch methods per target

| Target | Method | Why |
|---|---|---|
| Phone | `tel:` (direct) | Apple's public documented URL scheme. Opens the Phone app with no number supplied — verified on-device (see `docs/verification.md`). Shortcut fallback (`Open Phone`) if that ever fails. |
| Messages | `sms:` (direct) | Apple's public documented URL scheme; opens Messages with no recipient. No fallback needed — it's reliable. |
| Camera | Shortcut only (`Open Camera`) | No public URL scheme or Universal Link opens Camera.app. Shortcuts' own "Open App" action is Apple's supported way to do this, so it's the *primary* method, not a fallback. |
| Music | `https://music.apple.com/` (Universal Link) | Apple-owned domain; iOS hands off to the Music app when installed. Shortcut fallback (`Open Music`). |
| Podcasts | `https://podcasts.apple.com/` (Universal Link) | Same reasoning as Music. Shortcut fallback (`Open Podcasts`). |
| Soundcore | Shortcut only (`Open Soundcore`) | Anker publishes no public URL scheme for the soundcore app. Guessing one is explicitly out of scope — see "Known limitations". |
| Settings | Shortcut only (`Open Settings`) | `UIApplication.openSettingsURLString` only opens *this app's* Settings page, not Settings' root — using it to mean "open Settings" would misrepresent the app. No public API opens Settings' root screen. |

The single source of truth is `Shared/LaunchCatalog.swift` — read the doc comment there for the
full research summary. `PlainLaunchTests/LaunchCatalogTests.swift` asserts, among other things,
that the catalog never references an undocumented scheme (`App-Prefs:`, `prefs:`, `camera://`,
...).

## Shortcuts fallback

Three targets (Camera, Soundcore, Settings) need a user-created Shortcut — this is a real iOS
constraint, not a workaround PlainLaunch could avoid. The app is honest about this everywhere:
the Test tab shows a "Needs Shortcut" badge, and it works fine (no crash, no error) even if the
shortcut doesn't exist yet — tapping it just tells you nothing happened and to create one.

For each, in the **Shortcuts** app:

> **+** → Add Action → **"Open App"** → choose the target app → name the shortcut exactly:
> - `Open Camera` (target app: Camera)
> - `Open Soundcore` (target app: Anker soundcore)
> - `Open Settings` (target app: Settings)
> - optionally `Open Phone` / `Open Music` / `Open Podcasts` as a fallback for the direct methods

Names must match exactly (`Shared/LaunchMethod.swift`'s `ShortcutName` enum) — PlainLaunch calls
`shortcuts://run-shortcut?name=<exact name>`, Apple's own public URL scheme for the Shortcuts app.

## Customization

The Customize tab (backed by `WidgetDisplayConfiguration`, stored via `WidgetSettingsStore` in
the `group.com.ponk1tech.plainlaunch` App Group) lets you:

- enable/disable each item, reorder them, rename them,
- set text alignment (left/center/right), font size, font weight, line spacing,
- set text color and background color.

Every change calls `WidgetCenter.shared.reloadAllTimelines()` so the widget updates immediately.
The Customize tab's live preview uses the exact same `WidgetRowsView` the widget itself renders.

## Tests

```sh
make test
```

Covers `DeepLinkParser`, `LaunchCatalog` (including the "no private schemes" guard),
`LaunchCoordinator` (with a mocked `URLOpening` — no UIKit/simulator needed), and
`WidgetDisplayConfiguration` (JSON round-trip, reconciliation) / `WidgetSettingsStore`.

## Privacy

No account, no server, no analytics, no ads, no tracking, no third-party SDKs. The only thing
PlainLaunch stores is your widget settings, in a local App Group container — see the published
[Privacy Policy](https://ponk1-tech.com/plainlaunch/privacy.html) /
[Support page](https://ponk1-tech.com/plainlaunch/support.html) (source: `docs/`, served via
GitHub Pages) and
`PlainLaunch/PrivacyInfo.xcprivacy` / `PlainLaunchWidget/PrivacyInfo.xcprivacy` for the Required
Reason API declaration (`NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` — reading/
writing App Group-shared UserDefaults).

## App Store release

See [`docs/release.md`](docs/release.md) for the full runbook (first release vs. every release
after). Short version:

```sh
make icon           # regenerate the App Icon (tools/AppIcon/generate_icon.py)
make screenshots     # capture App Store screenshots (ja + en) via Simulator
make screenshots-upload  # push them to App Store Connect via the API
make archive         # Release archive + .ipa export
make validate        # validate the .ipa with the App Store Connect API
make upload          # upload it
make testflight      # poll processing, attach to internal TestFlight
make metadata        # push App Store text content (AppStore/metadata.json) via the API
make submit          # attach the build to the version and submit for review
```

## App Store Connect API setup

Uses a **Team API Key** (not an individual key), authenticated via a short-lived ES256 JWT
generated fresh for every request (`scripts/asc_api.js` / `scripts/asc_jwt.js` — never cached to
disk, never logged).

```sh
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_PRIVATE_KEY_PATH=$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
```

Put these in a local `.env.local` (already git-ignored) and `source` it, or export them in your
shell profile. **The `.p8` file itself is never read into git** — only its path is referenced.

The key used for this project has the **App Manager** role: enough to manage bundle IDs,
provisioning, builds, TestFlight, and metadata, without the account-holder-only powers (like
managing users or legal agreements) that a broader role would carry.

## Known limitations

- **App record creation is not exposed by the App Store Connect API** (`POST /v1/apps` returns
  `403 FORBIDDEN_ERROR`, confirmed live) — the very first app record has to be created once in
  the App Store Connect web UI. Everything after that (bundle ID, App Group, metadata, builds,
  TestFlight, submission) is scripted. See `docs/release.md`.
- **App Privacy ("Data Not Collected") does not appear in the App Store Connect API's app
  relationships either** (confirmed live against an existing app in the same account) — it's a
  web-UI-only declaration/publish step, done once per version.
- Camera, Soundcore, and Settings cannot be opened directly by any app on iOS — this is a
  platform constraint, not a gap in PlainLaunch. See "Launch methods per target" above.
- `Shared/ExperimentalLaunchMethod.swift` documents undocumented schemes some other apps use
  (`App-Prefs:`, `camera://`) for reference, but `LaunchCatalog` — the only thing that ships —
  never references them. Do not wire them into `LaunchCoordinator` for a Release build.
- Primary test/development device for this project so far has been a Simulator plus whatever
  physical iPhone happens to be connected during development; final verification on the specific
  target device (iPhone 8, iOS 16) still needs that device connected and unlocked once — see
  `docs/verification.md`.
