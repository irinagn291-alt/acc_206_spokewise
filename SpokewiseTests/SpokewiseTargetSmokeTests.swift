import XCTest
@testable import Spokewise

final class SpokewiseTargetSmokeTests: XCTestCase {
    func test_givenTestBundle_whenReadingIdentifier_thenItMatchesTheConfiguredValue() {
        let bundle = Bundle(for: SpokewiseTargetSmokeTests.self)
        let identifier = bundle.infoDictionary?["CFBundleIdentifier"] as? String
        XCTAssertEqual(identifier, "cc.spokewise.wheel.tests")
    }
}
