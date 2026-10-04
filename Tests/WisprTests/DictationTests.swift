import XCTest
import Combine
@testable import Wispr

final class DictationTests: XCTestCase {
    func testOldHistoryLoadsWithoutOptionalMetadataAndRebuildsWordCount() throws {
        let json = """
        {"id":"DC252CD4-BE8A-493B-B680-F7201F660001",
         "text":"one  two\\nthree", "date":0, "duration":2}
        """
        let item = try JSONDecoder().decode(Dictation.self, from: Data(json.utf8))
        XCTAssertEqual(item.wordCount, 3)
        XCTAssertEqual(item.latency, 0)
        XCTAssertNil(item.appName)
    }

    func testHistoryRoundTripPreservesMetadataWithoutPersistingDerivedCache() throws {
        let item = Dictation(text: "hello world", date: Date(timeIntervalSince1970: 100),
                             duration: 3, latency: 0.2, appName: "Test Editor")
        let encoded = try JSONEncoder().encode(item)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(fields["wordCount"])
        XCTAssertEqual(try JSONDecoder().decode(Dictation.self, from: encoded), item)
    }

    @MainActor
    func testUnchangedMicrophonePermissionDoesNotRedrawEveryObservedView() {
        let model = AppModel(preview: true)
        model.refreshMic()
        var updates = 0
        let subscription = model.objectWillChange.sink { updates += 1 }
        model.refreshMic()
        model.refreshMic()
        XCTAssertEqual(updates, 0)
        withExtendedLifetime(subscription) {}
    }
}
