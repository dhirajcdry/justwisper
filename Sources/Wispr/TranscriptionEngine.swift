import Foundation

/// Unified transcription result across engines.
struct TranscriptionResult: Sendable {
    let text: String
    let confidence: Float
    init(text: String, confidence: Float = 1) {
        self.text = text
        self.confidence = confidence
    }
}

enum TranscribeMode: Sendable {
    case streaming   // fast, partial — while the user is still speaking
    case final       // best quality — once recording stops
}

enum EngineError: Error { case notReady }

/// Abstracts the speech-to-text backend so the app isn't tied to one engine.
/// Today: WhisperKit (Core ML). Tomorrow: Parakeet/MLX/Apple Speech can conform
/// to the same contract without touching the rest of the app.
protocol TranscriptionEngine: Actor {
    nonisolated var displayName: String { get }

    /// Download (if needed) and load the given model. `progress` reports 0...1.
    func prepare(model: String, progress: @escaping @Sendable (Double) -> Void) async throws

    /// Transcribe 16 kHz mono PCM samples.
    func transcribe(_ samples: [Float], mode: TranscribeMode) async throws -> TranscriptionResult

    /// Whether the model's files are already present locally (no network needed).
    nonisolated func modelExistsOnDisk(_ model: String) -> Bool
}
