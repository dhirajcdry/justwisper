import XCTest
@testable import Wispr

@MainActor
final class DeliveryFeedbackTests: XCTestCase {
    func testPasteShortcutUsesNormalFeedbackInEveryOverlayStyle() {
        for style in FlowBarStyle.allCases {
            let model = AppModel(preview: true)
            model.flowStyle = style
            model.presentInsertionResult(.pasteRequested, appName: "Ghostty")
            XCTAssertEqual(model.landedAppName, "Ghostty", "\(style)")
            XCTAssertNil(model.noticeText, "A sent shortcut is not a warning: \(style)")
            XCTAssertFalse(model.deliveryConfirmed)
        }
    }

    func testConfirmedInsertionAndActualFailureRemainDistinct() {
        let model = AppModel(preview: true)
        model.presentInsertionResult(.inserted, appName: "Editor")
        XCTAssertTrue(model.deliveryConfirmed)
        XCTAssertEqual(model.landedAppName, "Editor")
        model.presentInsertionResult(.failed("Destination unavailable"), appName: "Editor")
        XCTAssertNil(model.landedAppName)
        XCTAssertEqual(model.noticeText, "Destination unavailable")
    }
}

