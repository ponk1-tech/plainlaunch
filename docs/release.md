# Release runbook

## First release (has a few one-time manual steps)

These are one-time steps because the App Store Connect API doesn't expose them (confirmed live —
see README "Known limitations"), or because Apple's own account-security model requires a human
in the loop. Everything else in this document is scripted.

1. **App Store Connect Team API Key** — already set up for this project (see README "App Store
   Connect API setup"). If starting fresh elsewhere: App Store Connect → Users and Access → Keys
   → Team Keys → **+** → name it, Role = **App Manager** → Generate → download the `.p8` **once**
   (Apple only lets you download it once) → save it to `~/.appstoreconnect/private_keys/` →
   note the Key ID and Issuer ID.

2. **Bundle ID + App Group** — already registered via the API for this project
   (`com.ponk1tech.plainlaunch`, `com.ponk1tech.plainlaunch.Widget`, both with the `APP_GROUPS`
   capability enabled). For a new project: `POST /v1/bundleIds`, then
   `POST /v1/bundleIdCapabilities` with `capabilityType: APP_GROUPS`. The App Group identifier
   itself (`group.com.ponk1tech.plainlaunch`) is created automatically by Xcode's automatic
   signing the first time you archive/build with `-allowProvisioningUpdates` — the App Store
   Connect API has no endpoint to create App Groups directly.

3. **App Store Connect app record** (manual — API returns `403` on `POST /v1/apps`):
   Open <https://appstoreconnect.apple.com/apps> → **+** → **New App**, and enter:

   | Field | Value |
   |---|---|
   | Platform | iOS |
   | Name | PlainLaunch |
   | Primary Language | Japanese |
   | Bundle ID | com.ponk1tech.plainlaunch |
   | SKU | com.ponk1tech.plainlaunch |
   | User Access | Full Access |

   After this exists, every other App Store Connect step below is scripted.

4. `make archive && make validate && make upload` — builds, archives, exports, validates, and
   uploads the `.ipa`.

5. `make testflight` — polls build processing, then attaches the build to the internal
   TestFlight group. If you're the first internal tester, add yourself once in App Store Connect
   → TestFlight → Internal Testing → App Store Connect Users → **+** (needs your Apple ID —
   that's the one truly personal piece of information here).

6. `make metadata` — pushes name/subtitle/description/keywords/promotional text/what's new/
   privacy policy URL and sets the age rating, all from `AppStore/metadata.json`.

7. **App Privacy declaration** (manual — no API relationship exists for it, confirmed live):
   App Store Connect → App Privacy → **Get Started** → "Do you collect data from this app?" →
   **No** → **Publish**. PlainLaunch collects nothing, so this is accurate as written (see
   `docs/privacy.html`).

8. **Screenshots** — `make screenshots` captures them locally, `make screenshots-upload` pushes
   them to App Store Connect via the API (`appScreenshotSets`/`appScreenshots`: reserve → upload
   to the returned S3 URL → commit — the same pattern used for build uploads). Apple's public
   `ScreenshotDisplayType` enum documentation was inconsistent about the newer 6.9" value as of
   this writing, so the script tries a short candidate list (`APP_IPHONE_69`, `APP_IPHONE_67`,
   `APP_IPHONE_65`) and uses whichever the API accepts — check its output the first time you run
   it.

9. `make submit` — attaches the processed build to the 1.0.0 version and creates the App Store
   review submission via the API.

## Every release after the first

```sh
make archive validate upload testflight metadata submit
```

Build numbers auto-increment from `git rev-list --count HEAD`, so every commit produces a new,
unique build number automatically — no manual bump needed. Bump `MARKETING_VERSION` in
`project.yml` for a new version string, and add a matching entry in `AppStore/metadata.json`
before running `make metadata`.

## If App Review rejects the build

1. Fetch the rejection: `GET /v1/appStoreVersions/{id}/appStoreReviewDetail` and/or check the
   **Resolution Center** in App Store Connect for the reviewer's message.
2. Map it to the specific Guideline cited, re-read the relevant section of
   `docs/app-review-notes.md`.
3. Fix the code and/or metadata, `make test`, then `make archive validate upload testflight
   metadata submit` again.
4. If a reply to Apple is needed and the facts are unambiguous (e.g. "here's exactly how to test
   the Test tab"), draft it for review before sending — never invent claims about the app's
   behavior.
