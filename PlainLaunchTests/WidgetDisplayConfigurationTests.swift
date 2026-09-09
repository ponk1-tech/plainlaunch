import XCTest
@testable import PlainLaunch

final class WidgetDisplayConfigurationTests: XCTestCase {
    func test_default_containsAllTargetsEnabledInDefaultOrder() {
        let config = WidgetDisplayConfiguration.default
        XCTAssertEqual(config.items.map(\.target), LaunchTarget.defaultOrder)
        XCTAssertTrue(config.items.allSatisfy(\.isEnabled))
    }

    func test_visibleItems_excludesDisabledItems() {
        var config = WidgetDisplayConfiguration.default
        config.items[0].isEnabled = false
        XCTAssertFalse(config.visibleItems.contains(where: { $0.target == config.items[0].target }))
        XCTAssertEqual(config.visibleItems.count, config.items.count - 1)
    }

    func test_roundTripsThroughJSON() throws {
        var config = WidgetDisplayConfiguration.default
        config.items[0].customName = "でんわ"
        config.alignment = .center
        config.fontSize = 32
        config.textColorHex = "#00FF00"

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(WidgetDisplayConfiguration.self, from: data)

        XCTAssertEqual(decoded, config)
    }

    func test_reconciled_addsNewlyIntroducedTargetsAsEnabled() {
        var config = WidgetDisplayConfiguration.default
        config.items.removeAll { $0.target == .soundcore }

        let reconciled = config.reconciled()

        let soundcoreItem = reconciled.items.first { $0.target == .soundcore }
        XCTAssertNotNil(soundcoreItem)
        XCTAssertEqual(soundcoreItem?.isEnabled, true)
    }

    func test_reconciled_isIdempotentOnAnAlreadyValidConfiguration() {
        let config = WidgetDisplayConfiguration.default
        XCTAssertEqual(config.reconciled(), config)
    }
}
