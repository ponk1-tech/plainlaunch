import XCTest
@testable import PlainLaunch

final class DeepLinkParserTests: XCTestCase {
    func test_parsesEachValidTarget() {
        for target in LaunchTarget.allCases {
            let url = URL(string: "plainlaunch://open?target=\(target.rawValue)")!
            XCTAssertEqual(DeepLinkParser.parse(url), target)
        }
    }

    func test_rejectsWrongScheme() {
        let url = URL(string: "https://open?target=phone")!
        XCTAssertNil(DeepLinkParser.parse(url))
    }

    func test_rejectsWrongHost() {
        let url = URL(string: "plainlaunch://launch?target=phone")!
        XCTAssertNil(DeepLinkParser.parse(url))
    }

    func test_rejectsMissingTargetQueryItem() {
        let url = URL(string: "plainlaunch://open")!
        XCTAssertNil(DeepLinkParser.parse(url))
    }

    func test_rejectsUnknownTargetValue() {
        let url = URL(string: "plainlaunch://open?target=notARealTarget")!
        XCTAssertNil(DeepLinkParser.parse(url))
    }

    func test_urlForTarget_roundTrips() {
        for target in LaunchTarget.allCases {
            let url = DeepLinkParser.url(for: target)
            XCTAssertEqual(DeepLinkParser.parse(url), target)
        }
    }
}
