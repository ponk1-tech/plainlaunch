# Verification log

Tracks what's been verified, on what, and what's still open. Updated as testing progresses.

## Automated

| Check | Status | How |
|---|---|---|
| Unit tests (24 tests: DeepLinkParser, LaunchCatalog, LaunchCoordinator, WidgetDisplayConfiguration, WidgetSettingsStore) | ✅ pass | `make test` (iOS 16 Simulator) |
| Debug build, iOS Simulator | ✅ succeeds | `make build` |
| Release archive + .ipa export | ⬜ not yet run | needs an App Store Connect app record to exist first (see `docs/release.md`) |
| App boots, all 4 tabs render correctly (ja + en) | ✅ verified | `scripts/screenshots.sh`; see `AppStore/screenshots/{ja,en}/tab{0-3}.png` |
| Widget preview renders (black bg, white text, left-aligned, matches target mockup) | ✅ verified | Customize tab screenshot — uses the exact `WidgetRowsView` the real widget renders |

## Manual / on-device (needs a human to look at the screen)

Simulator behavior for these targets is not representative (Simulator has no Phone/Messages/
Camera/cellular stack, and `tel:`/`sms:` behave differently than on a real device), so these are
only meaningfully verifiable on a physical iPhone. Report back as e.g. "Phone OK", "Camera NG".

| # | Target | Result | Notes |
|---|---|---|---|
| 1 | App launches on real device | ⬜ pending | needs a device connected via USB + unlocked (see below) |
| 2 | Widget can be added to a real Home Screen, Large size | ⬜ pending | |
| 3 | Phone | ⬜ pending | expect `tel:` to open the Phone app directly |
| 4 | Messages | ⬜ pending | expect `sms:` to open Messages directly |
| 5 | Camera | ⬜ pending | expect it to need the `Open Camera` Shortcut |
| 6 | Music | ⬜ pending | expect the Universal Link to open the Music app |
| 7 | Podcasts | ⬜ pending | expect the Universal Link to open the Podcasts app |
| 8 | Soundcore | ⬜ pending | expect it to need the `Open Soundcore` Shortcut |
| 9 | Settings | ⬜ pending | expect it to need the `Open Settings` Shortcut |

### Blocker as of 2026-09-09

No iPhone was available connected-and-unlocked-over-USB during this session to complete the
on-device pass above. `g's iPhone16e` is paired but shows `connected (no DDI)` /
`The developer disk image could not be mounted on this device` via `xcrun devicectl` — this is
iOS asking for a fresh USB connection + unlock + Trust This Computer + Developer Mode check, not
a build issue (`scripts/device.sh` detects this exact condition and prints the same guidance).

Separately, `group.com.ponk1tech.plainlaunch` (the App Group identifier) still needs a one-time
manual registration — see `docs/release.md` step 2 — before either a device install or a Release
archive will successfully sign, since both entitlements files reference it. Everything else
(certificates, provisioning profiles, manual signing, build numbering) is already working and
verified via `scripts/provisioning.sh` and `scripts/archive.sh` (confirmed live: archive gets all
the way to the code-signing step and fails on exactly this one missing App Group, nothing else).
The project's actual target device, an iPhone 8, was not connected at all during this session.

Once a device (ideally the iPhone 8) is connected and unlocked:

```sh
./scripts/device.sh install
./scripts/device.sh launch
```

then walk through the table above and report results.
