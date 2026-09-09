import UIKit
import XCTest
@testable import PlainLaunch

@MainActor
final class LaunchCoordinatorTests: XCTestCase {
    /// Records every `open(_:)` call and lets a test script exactly which URLs "succeed", so
    /// these tests never touch a real device or the simulator's actual apps.
    final class MockApplication: URLOpening {
        var openableURLs: Set<URL> = []
        var openResults: [URL: Bool] = [:]
        private(set) var openedURLs: [URL] = []

        func canOpenURL(_ url: URL) -> Bool {
            openableURLs.contains(url)
        }

        func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completionHandler: (@Sendable (Bool) -> Void)?) {
            openedURLs.append(url)
            completionHandler?(openResults[url] ?? false)
        }
    }

    func test_messages_opensSmsDirectly_noFallbackAttempted() {
        let mock = MockApplication()
        mock.openResults[URL(string: "sms:")!] = true
        let coordinator = LaunchCoordinator(application: mock)

        coordinator.launch(.messages)

        XCTAssertEqual(coordinator.lastResult[.messages], .openedDirectly)
        XCTAssertEqual(mock.openedURLs, [URL(string: "sms:")!])
    }

    func test_phone_fallsBackToShortcut_whenTelFails() {
        let mock = MockApplication()
        mock.openResults[URL(string: "tel:")!] = false
        mock.openableURLs = [URL(string: "shortcuts://")!]
        let runURL = LaunchCoordinator.runShortcutURL(name: ShortcutName.openPhone)!
        mock.openResults[runURL] = true
        let coordinator = LaunchCoordinator(application: mock)

        coordinator.launch(.phone)

        XCTAssertEqual(coordinator.lastResult[.phone], .openedViaShortcut(name: ShortcutName.openPhone))
    }

    func test_camera_hasNoDirectMethod_goesStraightToShortcut() {
        let mock = MockApplication()
        mock.openableURLs = [URL(string: "shortcuts://")!]
        let runURL = LaunchCoordinator.runShortcutURL(name: ShortcutName.openCamera)!
        mock.openResults[runURL] = true
        let coordinator = LaunchCoordinator(application: mock)

        coordinator.launch(.camera)

        XCTAssertEqual(coordinator.lastResult[.camera], .openedViaShortcut(name: ShortcutName.openCamera))
        XCTAssertFalse(mock.openedURLs.contains(URL(string: "tel:")!))
    }

    func test_shortcutTarget_whenShortcutsAppUnavailable_reportsUnavailable() {
        let mock = MockApplication() // openableURLs left empty: shortcuts:// can't be opened
        let coordinator = LaunchCoordinator(application: mock)

        coordinator.launch(.soundcore)

        XCTAssertEqual(coordinator.lastResult[.soundcore], .shortcutsAppUnavailable(name: ShortcutName.openSoundcore))
    }

    func test_targetWithNoFallback_reportsUnavailable_onDirectFailure() {
        let mock = MockApplication()
        mock.openResults[URL(string: "sms:")!] = false
        let coordinator = LaunchCoordinator(application: mock)

        coordinator.launch(.messages)

        XCTAssertEqual(coordinator.lastResult[.messages], .unavailable)
    }

    func test_music_fallsBackToShortcut_whenUniversalLinkFails() {
        let mock = MockApplication()
        mock.openResults[URL(string: "https://music.apple.com/")!] = false
        mock.openableURLs = [URL(string: "shortcuts://")!]
        let runURL = LaunchCoordinator.runShortcutURL(name: ShortcutName.openMusic)!
        mock.openResults[runURL] = true
        let coordinator = LaunchCoordinator(application: mock)

        coordinator.launch(.music)

        XCTAssertEqual(coordinator.lastResult[.music], .openedViaShortcut(name: ShortcutName.openMusic))
    }
}
