import XCTest
@testable import Wispr

final class TranscriptionTuningTests: XCTestCase {
    func testFinalPassKeepsDefaultDecodingOptions() {
        XCTAssertNil(TranscriptionTuning.options(for: .final))
    }

    func testPreviewAvoidsFallbackRetriesAndHasBoundedTokenWork() throws {
        let options = try XCTUnwrap(TranscriptionTuning.options(for: .streaming))
        XCTAssertEqual(options.temperatureFallbackCount, 0)
        XCTAssertEqual(options.sampleLength, 128)
        XCTAssertTrue(options.withoutTimestamps)
        XCTAssertFalse(options.wordTimestamps)
    }
}
