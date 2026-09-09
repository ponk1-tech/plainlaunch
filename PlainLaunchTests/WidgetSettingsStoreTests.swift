import XCTest
@testable import PlainLaunch

final class WidgetSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var store: WidgetSettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "test.group.\(UUID().uuidString)"
        store = WidgetSettingsStore(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_load_withNothingSaved_returnsDefault() {
        XCTAssertEqual(store.load(), .default)
    }

    func test_save_thenLoad_roundTrips() {
        var config = WidgetDisplayConfiguration.default
        config.alignment = .trailing
        config.items[0].isEnabled = false

        XCTAssertTrue(store.save(config))
        XCTAssertEqual(store.load(), config)
    }

    func test_load_withCorruptData_fallsBackToDefaultWithoutCrashing() {
        UserDefaults(suiteName: suiteName)?.set(Data([0xFF, 0x00]), forKey: "widgetConfiguration.v1")
        XCTAssertEqual(store.load(), .default)
    }
}
