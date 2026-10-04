import XCTest
import AVFoundation
@testable import Wispr

final class EngineSmokeTests: XCTestCase {
    private let model = ProcessInfo.processInfo.environment["WISPR_SMOKE_MODEL"] ?? "small.en"
    /// Explicit opt-in: uses a locally cached model, never records microphone audio.
    func testCachedModelLoadsAndTranscribes() async throws {
        guard ProcessInfo.processInfo.environment["WISPR_MODEL_SMOKE"] == "1" else {
            throw XCTSkip("Set WISPR_MODEL_SMOKE=1 to run local Core ML inference.")
        }
        let engine = WhisperEngine()
        guard engine.modelExistsOnDisk(model) else {
            throw XCTSkip("Requires an already downloaded \(model) model.")
        }
        let started = Date()
        try await engine.prepare(model: model) { _ in }
        print(String(format: "Cached \(model) model loaded in %.2fs", Date().timeIntervalSince(started)))
        let reused = Date()
        try await engine.prepare(model: model) { _ in }
        print(String(format: "In-memory \(model) model reused in %.4fs", Date().timeIntervalSince(reused)))
        _ = try await engine.transcribe(Array(repeating: 0, count: 16_000), mode: .streaming)
        _ = try await engine.transcribe(Array(repeating: 0, count: 16_000), mode: .final)
    }

    /// An optional real-speech fixture made locally by scripts/smoke-dictation.sh.
    func testRecognizesLocalSpeechFixture() async throws {
        guard let path = ProcessInfo.processInfo.environment["WISPR_SMOKE_AUDIO"] else {
            throw XCTSkip("Set WISPR_SMOKE_AUDIO to a generated 16 kHz mono speech fixture.")
        }
        let engine = WhisperEngine()
        guard engine.modelExistsOnDisk(model) else { throw XCTSkip("\(model) model is not cached.") }
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path),
                                  commonFormat: .pcmFormatFloat32, interleaved: false)
        XCTAssertEqual(file.processingFormat.sampleRate, 16_000)
        XCTAssertEqual(file.processingFormat.channelCount, 1)
        guard file.length > 0, file.length <= 30 * 16_000 else {
            XCTFail("Speech fixture must contain between 0 and 30 seconds of audio.")
            return
        }
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                   frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        try await engine.prepare(model: model) { _ in }
        let result = try await engine.transcribe(samples, mode: .final)
        XCTAssertTrue(result.text.lowercased().contains("local dictation test"),
                      "Expected the locally generated sample phrase to be recognized.")
    }

}
