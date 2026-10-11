import XCTest
@testable import Wispr

final class FlowBarStyleTests: XCTestCase {
    func testRetiredProofStyleMigratesToCaption() {
        XCTAssertEqual(FlowBarStyle(stored: "proof"), .caption)
        XCTAssertEqual(FlowBarStyle(stored: "ticker"), .ticker)
        XCTAssertNil(FlowBarStyle(stored: "nonsense"))
    }
}
