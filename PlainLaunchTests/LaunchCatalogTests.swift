import XCTest
@testable import PlainLaunch

final class LaunchCatalogTests: XCTestCase {
    func test_everyTarget_hasACatalogEntryMatchingItself() {
        for target in LaunchTarget.allCases {
            XCTAssertEqual(LaunchCatalog.info(for: target).target, target)
        }
    }

    func test_noExperimentalOrPrivateSchemesInTheCatalog() {
        // Guards the App Review-risk rule: LaunchCatalog (what actually ships) must never
        // reference an undocumented scheme like App-Prefs: or camera://.
        let bannedPrefixes = ["app-prefs:", "prefs:", "camera:"]
        for target in LaunchTarget.allCases {
            let info = LaunchCatalog.info(for: target)
            for method in [info.primary, info.fallback].compactMap({ $0 }) {
                if case .url(let url) = method {
                    let lowered = url.absoluteString.lowercased()
                    for banned in bannedPrefixes {
                        XCTAssertFalse(lowered.hasPrefix(banned), "\(target) uses banned scheme \(url)")
                    }
                }
            }
        }
    }

    func test_targetsRequiringShortcut_areExactlyCameraSoundcoreSettings() {
        XCTAssertEqual(Set(LaunchCatalog.targetsRequiringShortcut), [.camera, .soundcore, .settings])
    }

    func test_musicAndPodcasts_useAppleOwnedUniversalLinks() {
        if case .url(let url) = LaunchCatalog.info(for: .music).primary {
            XCTAssertEqual(url.host, "music.apple.com")
        } else {
            XCTFail("Music should use a direct URL")
        }
        if case .url(let url) = LaunchCatalog.info(for: .podcasts).primary {
            XCTAssertEqual(url.host, "podcasts.apple.com")
        } else {
            XCTFail("Podcasts should use a direct URL")
        }
    }
}
